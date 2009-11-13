module BackgrounDRb
  class Connection
    attr_accessor :server_ip,:server_port,:cluster_conn,:connection_status

    def initialize ip,port,cluster_conn
      @mutex = Mutex.new
      @server_ip = ip
      @server_port = port
      @cluster_conn = cluster_conn
      @connection_status = true
    end


    def establish_connection
      begin
        timeout(3) do
          @connection = TCPSocket.open(server_ip, server_port)
          @connection.setsockopt(Socket::IPPROTO_TCP,Socket::TCP_NODELAY,1)
        end
        @connection_status = true
      rescue Timeout::Error
        @connection_status = false
      rescue Exception => e
        @connection_status = false
      end
    end

    def write_data data
      begin
        flush_in_loop(data)
      rescue Errno::EAGAIN
        return
      rescue Errno::EPIPE
        establish_connection
        if @connection_status
          flush_in_loop(data)
        else
          @connection_status = false
          raise BackgrounDRb::BdrbConnError.new("Error while writing #{server_info}")
        end
      rescue
        establish_connection
        if @connection_status
          flush_in_loop(data)
        else
          @connection_status = false
          raise BackgrounDRb::BdrbConnError.new("Error while writing #{server_info}")
        end
      end
    end

    def server_info
      "#{server_ip}:#{server_port}"
    end

    def flush_in_loop(data)
      t_length = data.length
      loop do
        break if t_length <= 0
        written_length = @connection.write(data)
        raise "Error writing to socket" if written_length <= 0
        result = @connection.flush
        data = data[written_length..-1]
        t_length = data.length
      end
    end

    def dump_object data
      establish_connection
      raise BackgrounDRb::BdrbConnError.new("Error while connecting to the backgroundrb server #{server_info}") unless @connection_status

      object_dump = Marshal.dump(data)
      dump_length = object_dump.length.to_s
      length_str = dump_length.rjust(9,'0')
      final_data = length_str + object_dump
      @mutex.synchronize { write_data(final_data) }
    end

    def close_connection
      @connection.close
      @connection = nil
    end

    def ask_work p_data
      p_data[:type] = :async_invoke
      dump_object(p_data)
      bdrb_response = nil
      @mutex.synchronize { bdrb_response = read_from_bdrb() }
      close_connection
      bdrb_response
    end

    def new_worker p_data
      p_data[:type] = :start_worker
      dump_object(p_data)
      close_connection
      # RailsWorkerProxy.worker(p_data[:worker],p_data[:worker_key],self)
    end

    def worker_info(p_data)
      p_data[:type] = :worker_info
      dump_object(p_data)
      bdrb_response = nil
      @mutex.synchronize { bdrb_response = read_from_bdrb() }
      close_connection
      bdrb_response
    end

    def all_worker_info
      p_data = { }
      p_data[:type] = :all_worker_info
      dump_object(p_data)
      bdrb_response = nil
      @mutex.synchronize { bdrb_response = read_from_bdrb() }
      close_connection
      bdrb_response
    end

    def delete_worker p_data
      p_data[:type] = :delete_worker
      dump_object(p_data)
      close_connection
    end

    def read_object
      begin
        message_length_str = @connection.read(9)
        message_length = message_length_str.to_i
        message_data = @connection.read(message_length)
        return message_data
      rescue
        raise BackgrounDRb::BdrbConnError.new("Not able to connect #{server_info}")
      end
    end

    def gen_key options
      if BDRB_CONFIG[:backgroundrb][:result_storage] == 'memcache'
        key = [options[:worker],options[:worker_key],options[:job_key]].compact.join('_')
        key
      else
        options[:job_key]
      end
    end

    def ask_result(p_data)
      if BDRB_CONFIG[:backgroundrb][:result_storage] == 'memcache'
        return_result_from_memcache(p_data)
      else
        p_data[:type] = :get_result
        dump_object(p_data)
        bdrb_response = nil
        @mutex.synchronize { bdrb_response = read_from_bdrb() }
        close_connection
        bdrb_response ? bdrb_response[:data] : nil
      end
    end

    def read_from_bdrb(timeout = 3)
      begin
        ret_val = select([@connection],nil,nil,timeout)
        return nil unless ret_val
        raw_response = read_object()
        master_response = Marshal.load(raw_response)
        return master_response
      rescue
        return nil
      end
    end

    def send_request(p_data)
      p_data[:type] = :sync_invoke
      dump_object(p_data)
      bdrb_response = nil
      @mutex.synchronize { bdrb_response = read_from_bdrb(nil) }
      close_connection
      bdrb_response
    end
  end
end
