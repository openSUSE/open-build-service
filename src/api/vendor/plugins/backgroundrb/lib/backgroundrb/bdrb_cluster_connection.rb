# class stores connections to BackgrounDRb servers in a cluster manner
module BackgrounDRb
  class ClusterConnection
    include ClientHelper
    attr_accessor :backend_connections,:config,:cache,:bdrb_servers
    attr_accessor :disconnected_connections

    # initialize cluster connection
    def initialize
      @bdrb_servers = []
      @backend_connections = []
      @disconnected_connections = {}

      @last_polled_time = Time.now
      @request_count = 0

      initialize_memcache if BDRB_CONFIG[:backgroundrb][:result_storage] == 'memcache'
      establish_connections
      @round_robin = (0...@backend_connections.length).to_a
    end

    # initialize memache if client is storing results in memcache
    def initialize_memcache
      require 'memcache'
      memcache_options = {
        :c_threshold => 10_000,
        :compression => true,
        :debug => false,
        :namespace => 'backgroundrb_result_hash',
        :readonly => false,
        :urlencode => false
      }
      @cache = MemCache.new(memcache_options)
      @cache.servers = BDRB_CONFIG[:memcache].split(',')
    end

    # initialize all backend server connections
    def establish_connections
      klass = Struct.new(:ip,:port)
      if t_servers = BDRB_CONFIG[:client]
        connections = t_servers.split(',')
        connections.each do |conn_string|
          ip = conn_string.split(':')[0]
          port = conn_string.split(':')[1].to_i
          @bdrb_servers << klass.new(ip,port)
        end
      end
      @bdrb_servers << klass.new(BDRB_CONFIG[:backgroundrb][:ip],BDRB_CONFIG[:backgroundrb][:port].to_i)
      @bdrb_servers.each_with_index do |connection_info,index|
        next if @backend_connections.detect { |x| x.server_info == "#{connection_info.ip}:#{connection_info.port}" }
        @backend_connections << Connection.new(connection_info.ip,connection_info.port,self)
      end
    end # end of method establish_connections

    # every 10 request or 10 seconds it will try to reconnect to bdrb servers which were down
    def discover_server_periodically
      @disconnected_connections.each do |key,connection|
        connection.establish_connection
        if connection.connection_status
          @backend_connections << connection
          connection.close_connection
          @disconnected_connections[key] = nil
        end
      end
      @disconnected_connections.delete_if { |key,value| value.nil? }
      @round_robin = (0...@backend_connections.length).to_a
    end

    # Find live connections except those mentioned in array, because they
    # are already dead.
    def find_next_except_these connections
      invalid_connections = @backend_connections.select { |x| connections.include?(x.server_info) }
      @backend_connections.delete_if { |x| connections.include?(x.server_info) }
      @round_robin = (0...@backend_connections.length).to_a
      invalid_connections.each do |x|
        @disconnected_connections[x.server_info] = x
      end
      chosen = @backend_connections.detect { |x| !(connections.include?(x.server_info)) }
      raise NoServerAvailable.new("No BackgrounDRb server is found running") unless chosen
      chosen
    end

    # Fina a connection by host name and port
    def find_connection host_info
      conn = @backend_connections.detect { |x| x.server_info == host_info }
      raise NoServerAvailable.new("BackgrounDRb server is not found running on #{host_info}") unless conn
      return conn
    end

    # find the local configured connection
    def find_local
      find_connection("#{BDRB_CONFIG[:backgroundrb][:ip]}:#{BDRB_CONFIG[:backgroundrb][:port]}")
    end

    # return the worker proxy
    def worker(worker_name,worker_key = nil)
      update_stats
      RailsWorkerProxy.new(worker_name,worker_key,self)
    end

    # Update the stats and discover new nodes if they came up.
    def update_stats
      @request_count += 1
      discover_server_periodically if(time_to_discover? && !@disconnected_connections.empty?)
    end

    # Check if, we should try to discover new bdrb servers
    def time_to_discover?
      if((@request_count%10 == 0) or (Time.now > (@last_polled_time + 10.seconds)))
        @last_polled_time = Time.now
        return true
      else
        return false
      end
    end

    # Send worker information of all currently running workers from all configured bdrb
    # servers
    def all_worker_info
      update_stats
      info_data = {}
      @backend_connections.each do |t_connection|
        info_data[t_connection.server_info] = t_connection.all_worker_info rescue nil
      end
      return info_data
    end

    # one of the backend connections are chosen and worker is started on it
    def new_worker(options = {})
      update_stats
      succeeded = false
      result = nil

      @backend_connections.each do |connection|
        begin
          result = connection.new_worker(options)
          succeeded = true
        rescue BdrbConnError; end
      end
      raise NoServerAvailable.new("No BackgrounDRb server is found running") unless succeeded
      return options[:worker_key]
    end

    # choose a server in round robin manner.
    def choose_server
      if @round_robin.empty?
        @round_robin = (0...@backend_connections.length).to_a
      end
      if @round_robin.empty? && @backend_connections.empty?
        discover_server_periodically
        raise NoServerAvailable.new("No BackgrounDRb server is found running") if @round_robin.empty? && @backend_connections.empty?
      end
      @backend_connections[@round_robin.shift]
    end
  end # end of ClusterConnection
end # end of Module BackgrounDRb
