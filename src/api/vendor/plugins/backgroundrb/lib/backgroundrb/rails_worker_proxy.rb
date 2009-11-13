module BackgrounDRb
  # A Worker proxy, which uses +method_missing+ for delegating method calls to the workers
  class RailsWorkerProxy
    attr_accessor :worker_name, :worker_method, :data, :worker_key,:middle_man

    # create new worker proxy
    def initialize(p_worker_name,p_worker_key = nil,p_middle_man = nil)
      @worker_name = p_worker_name
      @middle_man = p_middle_man
      @worker_key = p_worker_key
      @tried_connections = []
    end

    def method_missing(method_id,*args)
      worker_method = method_id.to_s
      arguments = args.first

      arg,job_key,host_info,scheduled_at,priority = arguments && arguments.values_at(:arg,:job_key,:host,:scheduled_at, :priority)

      # allow both arg and args
      arg ||= arguments && arguments[:args]

      new_schedule = (scheduled_at && scheduled_at.respond_to?(:utc)) ? scheduled_at.utc : Time.now.utc

      if worker_method =~ /^async_(\w+)/
        method_name = $1
        worker_options = compact(:worker => worker_name,:worker_key => worker_key,
                                 :worker_method => method_name,:job_key => job_key, :arg => arg)
        run_method(host_info,:ask_work,worker_options)
      elsif worker_method =~ /^enq_(\w+)/i
        raise NoJobKey.new("Must specify a job key with enqueued tasks") if job_key.blank?
        method_name = $1
        marshalled_args = Marshal.dump(arg)
        enqueue_task(compact(:worker_name => worker_name.to_s,:worker_key => worker_key.to_s,
                             :worker_method => method_name.to_s,:job_key => job_key.to_s, :priority => priority,
                             :args => marshalled_args,:timeout => arguments ? arguments[:timeout] : nil,:scheduled_at => new_schedule))
       elsif worker_method =~ /^deq_(\w+)/i
        raise NoJobKey.new("Must specify a job key to dequeue tasks") if job_key.blank?
        method_name = $1
        dequeue_task(compact(:worker_name => worker_name.to_s,:worker_key => worker_key.to_s,
                             :worker_method => method_name.to_s,:job_key => job_key.to_s))
      else
        worker_options = compact(:worker => worker_name,:worker_key => worker_key,
                                 :worker_method => worker_method,:job_key => job_key,:arg => arg)
        run_method(host_info,:send_request,worker_options)
      end
    end

    # enqueue tasks to the worker pool
    def enqueue_task options = {}
      BdrbJobQueue.insert_job(options)
    end

    # remove tasks from the worker pool
    def dequeue_task options = {}
      BdrbJobQueue.remove_job(options)
    end

    # invoke method on worker
    def run_method host_info,method_name,worker_options = {}
      result = []
      connection = choose_connection(host_info)
      raise NoServerAvailable.new("No BackgrounDRb server is found running") if connection.blank?
      if host_info == :local or host_info.is_a?(String)
        result << invoke_on_connection(connection,method_name,worker_options)
      elsif host_info == :all
        succeeded = false
        begin
          connection.each { |conn| result << invoke_on_connection(conn,method_name,worker_options) }
          succeeded = true
        rescue BdrbConnError; end
        raise NoServerAvailable.new("No BackgrounDRb server is found running") unless succeeded
      else
        @tried_connections = [connection.server_info]
        begin
          result << invoke_on_connection(connection,method_name,worker_options)
        rescue BdrbConnError => e
          connection = middle_man.find_next_except_these(@tried_connections)
          @tried_connections << connection.server_info
          retry
        end
      end
      #return nil if method_name == :ask_work
      process_result(return_result(result))
    end

    def process_result t_result
      case t_result
      when Hash
        if(t_result[:result] == true && t_result[:type] = :response)
          if(t_result[:result_flag] == "ok")
            return t_result[:data]
          else
            raise RemoteWorkerError.new("Error while executing worker method")
          end
        elsif(t_result[:result_flag] == "ok")
          "ok"
        elsif(t_result[:result_flag] == "error")
          raise RemoteWorkerError.new("Error while executing worker method")
        end
      when Array
        t_result
      end
    end

    # choose a backgroundrb server connection and invoke worker method on it.
    def invoke_on_connection connection,method_name,options = {}
      raise NoServerAvailable.new("No BackgrounDRb is found running") unless connection
      connection.send(method_name,options)
    end

    # get results back from the cache. Cache can be in-memory worker cache or memcache
    # based cache
    def ask_result job_key
      options = compact(:worker => worker_name,:worker_key => worker_key,:job_key => job_key)
      if BDRB_CONFIG[:backgroundrb][:result_storage] == 'memcache'
        return_result_from_memcache(options)
      else
        result = middle_man.backend_connections.map { |conn| conn.ask_result(options) }
        return_result(result)
      end
    end

    # return runtime information about worker
    def worker_info
      t_connections = middle_man.backend_connections
      result = t_connections.map { |conn| conn.worker_info(compact(:worker => worker_name,:worker_key => worker_key)) }
      return_result(result)
    end

    # generate worker key
    def gen_key options
      key = [options[:worker],options[:worker_key],options[:job_key]].compact.join('_')
      key
    end

    # return result from memcache
    def return_result_from_memcache options = {}
      middle_man.cache[gen_key(options)]
    end

    # reset result within memcache for given key
    def reset_memcache_result(job_key,value)
      options = compact(:worker => worker_name,:worker_key => worker_key,\
                          :job_key => job_key)
      key = gen_key(options)
      middle_man.cache[key] = value
      value
    end

    def return_result result
      result = Array(result)
      result.size <= 1 ? result[0] : result
    end

    # delete a worker
    def delete
      middle_man.backend_connections.each do |connection|
        connection.delete_worker(compact(:worker => worker_name, :worker_key => worker_key))
      end
      return worker_key
    end

    # choose a worker
    def choose_connection host_info
      case host_info
      when :all; middle_man.backend_connections
      when :local; middle_man.find_local
      when String; middle_man.find_connection(host_info)
      else; middle_man.choose_server
      end
    end

    # helper method to compact a hash and for getting rid of nil parameters
    def compact(options = { })
      options.delete_if { |key,value| value.nil? }
      options
    end
  end # end of RailsWorkerProxy class

end # end of BackgrounDRb module
