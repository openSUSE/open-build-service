module BackgrounDRb
  # this class is a dummy class that implements things required for passing data to
  # actual logger worker
  class PacketLogger
    def initialize(worker,log_flag = true)
      @log_flag = log_flag
      @worker = worker
      @log_mutex = Mutex.new
    end
    [:info,:debug,:warn,:error,:fatal].each do |m|
      define_method(m) do |log_data|
        return unless @log_flag
        @log_mutex.synchronize do
          @worker.send_request(:worker => :log_worker, :data => log_data)
        end
      end
    end
  end
  # == MetaWorker class
  # BackgrounDRb workers are asynchronous reactors which work using events
  # You are free to use threads in your workers, but be reasonable with them.
  # Following methods are available to all workers from parent classes.
  # * BackgrounDRb::MetaWorker#connect
  #
  #   Above method connects to an external tcp server and integrates the connection
  #   within reactor loop of worker. For example:
  #
  #        class TimeClient
  #          def receive_data(p_data)
  #            worker.get_external_data(p_data)
  #          end
  #
  #          def post_init
  #            p "***************** : connection completed"
  #          end
  #        end
  #
  #        class FooWorker < BackgrounDRb::MetaWorker
  #          set_worker_name :foo_worker
  #          def create(args = nil)
  #            external_connection = nil
  #            connect("localhost",11009,TimeClient) { |conn| conn = external_connection }
  #          end
  #
  #          def get_external_data(p_data)
  #            puts "And external data is : #{p_data}"
  #          end
  #        end
  # * BackgrounDRb::MetaWorker#start_server
  #
  #   Above method allows you to start a tcp server from your worker, all the
  #   accepted connections are integrated with event loop of worker
  #      class TimeServer
  #
  #        def receive_data(p_data)
  #        end
  #
  #        def post_init
  #          add_periodic_timer(2) { say_hello_world }
  #        end
  #
  #        def connection_completed
  #        end
  #
  #        def say_hello_world
  #          p "***************** : invoking hello world #{Time.now}"
  #          send_data("Hello World\n")
  #        end
  #      end
  #
  #      class ServerWorker < BackgrounDRb::MetaWorker
  #        set_worker_name :server_worker
  #        def create(args = nil)
  #          # start the server when worker starts
  #          start_server("0.0.0.0",11009,TimeServer) do |client_connection|
  #            client_connection.say_hello_world
  #          end
  #        end
  #      end

  class MetaWorker < Packet::Worker
    include BackgrounDRb::BdrbServerHelper
    attr_accessor :config_file, :my_schedule, :run_time, :trigger_type, :trigger
    attr_accessor :logger, :thread_pool,:cache
    iattr_accessor :pool_size
    iattr_accessor :reload_flag

    @pool_size = nil
    @reload_flag = false

    # set the thread pool size, default is 20
    def self.pool_size(size = nil)
      @pool_size = size if size
      @pool_size
    end

    # set auto restart flag on the worker
    def self.reload_on_schedule(flag = nil)
      if flag
        self.no_auto_load = true
        self.reload_flag = true
      end
    end

    # does initialization of worker stuff and invokes create method in
    # user defined worker class
    def worker_init
      raise "Invalid worker name" if !worker_name
      Thread.abort_on_exception = true

      # stores the job key of currently running job
      Thread.current[:job_key] = nil
      initialize_logger

      @thread_pool = ThreadPool.new(self,pool_size || 20,@logger)
      t_worker_key = worker_options && worker_options[:worker_key]

      @cache = ResultStorage.new(worker_name,t_worker_key,BDRB_CONFIG[:backgroundrb][:result_storage])

      if(worker_options && worker_options[:schedule] && no_auto_load)
        load_schedule_from_args
      elsif(BDRB_CONFIG[:schedules] && BDRB_CONFIG[:schedules][worker_name.to_sym])
        @my_schedule = BDRB_CONFIG[:schedules][worker_name.to_sym]
        new_load_schedule if @my_schedule
      end
      if respond_to?(:create)
        invoke_user_method(:create,worker_options[:data])
      end
      if run_persistent_jobs?
        add_periodic_timer(persistent_delay.to_i) {
          begin
            check_for_enqueued_tasks
          rescue Object => e
            puts("Error while running persistent task : #{Time.now}")
            log_exception(e.backtrace)
          end
        }
      end
      write_pid_file(t_worker_key)
    end

    def write_pid_file t_worker_key
      key = [worker_name,t_worker_key].compact.join('_')
      pid_file = "#{RAILS_HOME}/tmp/pids/backgroundrb_#{BDRB_CONFIG[:backgroundrb][:port]}_worker_#{key}.pid"
      op = File.open(pid_file, "w")
      op.write(Process.pid().to_s)
      op.close
    end

    def initialize_logger
      log_flag = BDRB_CONFIG[:backgroundrb][:debug_log].nil? ? true : BDRB_CONFIG[:backgroundrb][:debug_load_rails_env]
      if BDRB_CONFIG[:backgroundrb][:logging_logger].nil?
        @logger = PacketLogger.new(self,log_flag)
      else
        log_config = BDRB_CONFIG[:backgroundrb][:logging_logger]
        @logger = Logging::Logger[log_config[:name]]
        @logger.trace = log_config[:trace]
        @logger.additive = log_config[:additive]

        log_config[:appenders].keys.each do |key|
          appender_config = log_config[:appenders][key]

          logger_options = {
            :filename => "#{RAILS_HOME}/#{appender_config[:filename]}",
            :age => appender_config[:age],
            :size => appender_config[:size],
            :keep => appender_config[:keep],
            :safe => appender_config[:safe],
            :layout => Logging::Layouts::Pattern.new(:pattern => appender_config[:layout_pattern])
          }
          appender = "Logging::Appenders::#{appender_config[:type]}".constantize.new("backgroundrb_#{key}",logger_options)
          @logger.add_appenders(appender)
        end
      end
    end

    def puts msg
      STDOUT.puts msg
      STDOUT.flush
    end

    # Returns the persistent job queue check delay for this worker
    def persistent_delay
      get_config_value(:persistent_delay, 5)
    end

    # Returns true if persistent jobs should be run for this worker.
    def run_persistent_jobs?
      !get_config_value(:persistent_disabled, false)
    end

    # return job key from thread global variable
    def job_key; Thread.current[:job_key]; end

    # if worker is running using a worker key, return it
    def worker_key; worker_options && worker_options[:worker_key]; end

    # fetch the persistent job id of job currently running, create AR object
    # and return to the user.
    def persistent_job
      job_id = Thread.current[:persistent_job_id]
      job_id ? BdrbJobQueue.find_by_id(job_id) : nil
    end

    # loads workers schedule from options supplied from rails
    # a user may pass trigger arguments to dynamically define the schedule
    def load_schedule_from_args
      @my_schedule = worker_options[:schedule]
      new_load_schedule if @my_schedule
    end

    # Gets called, whenever master bdrb process sends any data to the worker
    def receive_internal_data data
      @tokenizer.extract(data) do |b_data|
        data_obj = load_data(b_data)
        receive_data(data_obj) if data_obj
      end
    end

    # receives requests/responses from master process or other workers
    def receive_data p_data
      if p_data[:data][:worker_method] == :exit
        exit
      end
      case p_data[:type]
      when :request: process_request(p_data)
      when :response: process_response(p_data)
      when :get_result: return_result_object(p_data)
      end
    end

    def return_result_object p_data
      user_input = p_data[:data]
      user_job_key = user_input[:job_key]
      send_response(p_data,cache[user_job_key])
    end

    # method is responsible for invoking appropriate method in user
    def process_request(p_data)
      user_input = p_data[:data]
      if (user_input[:worker_method]).nil? or !respond_to?(user_input[:worker_method])
        result = nil
        puts "Trying to invoke invalid worker method on worker #{worker_name}"
        send_response(p_data,result,"error")
        return
      end

      result = nil

      Thread.current[:job_key] = user_input[:job_key]

      result,result_flag = invoke_user_method(user_input[:worker_method],user_input[:arg])

      if p_data[:result]
        result = "dummy_result" if result.nil?
        if can_dump?(result)
          send_response(p_data,result,result_flag)
        else
          send_response(p_data,"dummy_result","error")
        end
      end
    end

    # can the responses be dumped?
    def can_dump?(p_object)
      begin
        Marshal.dump(p_object)
        return true
      rescue TypeError
        return false
      rescue
        return false
      end
    end

    # Load the schedule of worker from my_schedule instance variable
    def new_load_schedule
      @worker_method_triggers = { }
      @my_schedule.each do |key,value|
        case value[:trigger_args]
        when String
          cron_args = value[:trigger_args] || "0 0 0 0 0"
          trigger = BackgrounDRb::CronTrigger.new(cron_args)
          @worker_method_triggers[key] = { :trigger => trigger,:data => value[:data],:runtime => trigger.fire_after_time(Time.now).to_i }
        when Hash
          trigger = BackgrounDRb::Trigger.new(value[:trigger_args])
          @worker_method_triggers[key] = { :trigger => trigger,:data => value[:trigger_args][:data],:runtime => trigger.fire_after_time(Time.now).to_i }
        end
      end
    end

    # send the response back to master process and hence to the client
    # if there is an error while dumping the object, send "invalid_result_dump_check_log"
    def send_response input,output,result_flag = "ok"
      input[:data] = output
      input[:type] = :response
      input[:result_flag] = result_flag
      begin
        send_data(input)
      rescue Object => bdrb_error
        log_exception(bdrb_error)
        input[:data] = "invalid_result_dump_check_log"
        input[:result_flag] = "error"
        send_data(input)
      end
    end

    def log_exception exception_object
      if exception_object.is_a?(Array)
        STDERR.puts exception_object.each { |e| e << "\n" }
      else
        STDERR.puts exception_object.to_s
      end
      STDERR.flush
    end

    def invoke_user_method user_method,args
      if self.respond_to?(user_method)
        called_method_arity = self.method(user_method).arity
        t_result = nil
        begin
          if(called_method_arity != 0)
            t_result = self.send(user_method,args)
          else
            t_result = self.send(user_method)
          end
          [t_result,"ok"]
        rescue Object => bdrb_error
          puts "Error calling method #{user_method} with #{args} on worker #{worker_name} at #{Time.now}"
          log_exception(bdrb_error)
          [t_result,"error"]
        end
      else
        puts "Trying to invoke method #{user_method} with #{args} on worker #{worker_name} failed because no such method is defined on the worker at #{Time.now}"
        [nil,"error"]
      end
    end

    # called when connection is closed
    def unbind; end

    def connection_completed; end

    # Check for enqueued tasks and invoke appropriate methods
    def check_for_enqueued_tasks
      while (task = get_next_task)
        if self.respond_to? task.worker_method
          Thread.current[:persistent_job_id] = task[:id]
          Thread.current[:job_key] = task[:job_key]
          args = Marshal.load(task.args)
          invoke_user_method(task.worker_method,args)
        else
          task.release_job
        end
        # Unless configured to loop on persistent tasks, run only
        # once, and then break
        break unless BDRB_CONFIG[:backgroundrb][:persistent_multi]
      end
    end

    # Get the next enqueued job
    def get_next_task
      if worker_key && !worker_key.empty?
        BdrbJobQueue.find_next(worker_name.to_s,worker_key.to_s)
      else
        BdrbJobQueue.find_next(worker_name.to_s)
      end
    end

    # Check for timer events and invoke scheduled methods in timer and scheduler
    def check_for_timer_events
      super
      return if @worker_method_triggers.nil? or @worker_method_triggers.empty?
      @worker_method_triggers.delete_if { |key,value| value[:trigger].respond_to?(:end_time) && value[:trigger].end_time <= Time.now }

      @worker_method_triggers.each do |key,value|
        time_now = Time.now.to_i
        if value[:runtime] < time_now
          check_db_connection
          invoke_user_method(key,value[:data])
          t_time = value[:trigger].fire_after_time(Time.now)
          value[:runtime] = t_time.to_i
        end
      end
    end

    # Periodic check for lost database connections and closed connections
    def check_db_connection
      begin
        ActiveRecord::Base.verify_active_connections! if defined?(ActiveRecord)
      rescue Object => bdrb_error
        log_exception(bdrb_error)
      end
    end

    private

    # Returns the local configuration hash for this worker.  Returns an
    # empty hash if no local config exists.
    def worker_config
      if BDRB_CONFIG[:workers] && BDRB_CONFIG[:workers][worker_name.to_sym]
        BDRB_CONFIG[:workers][worker_name.to_sym]
      else
        {}
      end
    end

    # Returns the appropriate configuration value, based on both the
    # global config and the per-worker configuration for this worker.
    def get_config_value(key_sym, default)
      if !worker_config[key_sym].nil?
        worker_config[key_sym]
      elsif !BDRB_CONFIG[:backgroundrb][key_sym].nil?
        BDRB_CONFIG[:backgroundrb][key_sym]
      else
        default
      end
    end

    def load_rails_env
      db_config_file = YAML.load(ERB.new(IO.read("#{RAILS_HOME}/config/database.yml")).result)
      run_env = ENV["RAILS_ENV"]
      ActiveRecord::Base.establish_connection(db_config_file[run_env])
      if(Object.const_defined?(:Rails) && Rails.version < "2.2.2")
        ActiveRecord::Base.allow_concurrency = true
      elsif(Object.const_defined?(:RAILS_GEM_VERSION) && RAILS_GEM_VERSION < "2.2.2")
        ActiveRecord::Base.allow_concurrency = true
      end
    end

  end # end of class MetaWorker
end # end of module BackgrounDRb
