#!/usr/bin/env ruby
module BackgrounDRb
  # Class wraps a logger object for debugging internal errors within server
  class DebugMaster
    attr_accessor :log_mode,:logger,:log_flag
    def initialize(log_mode,log_flag = true)
      @log_mode = log_mode
      @log_flag = log_flag
      if @log_mode == :foreground
        @logger = ::Logger.new(STDOUT)
      else
        @logger = ::Logger.new("#{RAILS_HOME}/log/backgroundrb_debug_#{BDRB_CONFIG[:backgroundrb][:port]}.log")
      end
    end

    def info(data)
      return unless @log_flag
      @logger.info(data)
    end

    def debug(data)
      return unless @log_flag
      @logger.debug(data)
    end
  end

  class MasterWorker
    attr_accessor :debug_logger
    include BackgrounDRb::BdrbServerHelper
    # receives requests from rails and based on request type invoke appropriate method
    def receive_data p_data
      @tokenizer.extract(p_data) do |b_data|
        begin
          t_data = load_data b_data
          if t_data
            case t_data[:type]
              # async method invocation
            when :async_invoke: async_method_invoke(t_data)
              # get status/result
            when :get_result: get_result_object(t_data)
              # sync method invocation
            when :sync_invoke: method_invoke(t_data)
            when :start_worker: start_worker_request(t_data)
            when :delete_worker: delete_drb_worker(t_data)
            when :worker_info: pass_worker_info(t_data)
            when :all_worker_info: all_worker_info(t_data)
            else; debug_logger.info("Invalid request")
            end
          end
        rescue Object => bdrb_error
          debug_logger.info(bdrb_error)
          debug_logger.info(bdrb_error.backtrace.join("\n"))
          send_object(nil)
        end
      end
    end

    # Send worker info to the user
    def pass_worker_info(t_data)
      worker_name_key = gen_worker_key(t_data[:worker],t_data[:worker_key])
      worker_instance = reactor.live_workers[worker_name_key]
      info_response = { :worker => t_data[:worker],:worker_key => t_data[:worker_key]}
      worker_instance ? (info_response[:status] = :running) : (info_response[:status] = :stopped)
      send_object(info_response)
    end

    # collect all worker info in an array and send to the user
    def all_worker_info(t_data)
      info_response = []
      reactor.live_workers.each do |key,value|
        worker_key = (value.worker_key.to_s).gsub(/#{value.worker_name}_?/,"")
        info_response << { :worker => value.worker_name,:worker_key => worker_key,:status => :running }
      end
      send_object(info_response)
    end

    # Delete the worker. Sends TERM signal to the worker process and removes
    # worker key from list of available workers
    def delete_drb_worker(t_data)
      worker_name = t_data[:worker]
      worker_key = t_data[:worker_key]
      worker_name_key = gen_worker_key(worker_name,worker_key)
      begin
        worker_instance = reactor.live_workers[worker_name_key]
        raise Packet::InvalidWorker.new("Invalid worker with name #{worker_name} key #{worker_key}") unless worker_instance
        Process.kill('TERM',worker_instance.pid)
        # Warning: Change is temporary, may break things
        reactor.live_workers.delete(worker_name_key)
      rescue Packet::DisconnectError => sock_error
        reactor.remove_worker(sock_error)
      rescue
        debug_logger.info($!.to_s)
        debug_logger.info($!.backtrace.join("\n"))
      end
    end

    # start a new worker
    def start_worker_request(p_data)
      start_worker(p_data)
    end

    # Invoke an asynchronous method on a worker
    def async_method_invoke(t_data)
      worker_name = t_data[:worker]
      worker_name_key = gen_worker_key(worker_name,t_data[:worker_key])

      unless worker_methods(worker_name_key).include?(t_data[:worker_method])
        send_object(:result_flag => "error")
        return
      end

      t_data.delete(:worker)
      t_data.delete(:type)
      begin
        ask_worker(worker_name_key,:data => t_data, :type => :request, :result => false)
        send_object(:result_flag => "ok")
      rescue Packet::DisconnectError => sock_error
        send_object(:result_flag => "error")
        reactor.live_workers.delete(worker_name_key)
      rescue
        send_object(:result_flag => "error")
        debug_logger.info($!.message)
        debug_logger.info($!.backtrace.join("\n"))
        return
      end
    end

    def worker_methods worker_name_key
      reactor.live_workers[worker_name_key].invokable_worker_methods
    end

    # Given a cache key, ask the worker for result stored in it.
    # If you are using Memcache for result storage, this method won't be
    # called at all and bdrb client library will directly fetch
    # the results from memcache and return
    def get_result_object(t_data)
      worker_name = t_data[:worker]
      worker_name_key = gen_worker_key(worker_name,t_data[:worker_key])
      t_data.delete(:worker)
      t_data.delete(:type)
      begin
        ask_worker(worker_name_key,:data => t_data, :type => :get_result,:result => true)
      rescue Packet::DisconnectError => sock_error
        reactor.live_workers.delete(worker_name_key)
      rescue
        debug_logger.info($!.to_s)
        debug_logger.info($!.backtrace.join("\n"))
        return
      end
    end

    # Invoke a synchronous/blocking method on a worker.
    def method_invoke(t_data)
      worker_name = t_data[:worker]
      worker_name_key = gen_worker_key(worker_name,t_data[:worker_key])
      t_data.delete(:worker)
      t_data.delete(:type)
      begin
        ask_worker(worker_name_key,:data => t_data, :type => :request,:result => true)
      rescue Packet::DisconnectError => sock_error
        reactor.live_workers.delete(worker_name_key)
      rescue
        debug_logger.info($!.message)
        debug_logger.info($!.backtrace.join("\n"))
        return
      end
    end

    # Receieve responses from workers and dispatch them back to the client
    def worker_receive p_data
      p_data[:result_flag] ||= "ok"
      send_object(p_data)
    end

    def unbind; end

    # called whenever a new connection is made.Initializes binary data parser
    def post_init
      @tokenizer = Packet::BinParser.new
    end
    def connection_completed; end
  end
end




