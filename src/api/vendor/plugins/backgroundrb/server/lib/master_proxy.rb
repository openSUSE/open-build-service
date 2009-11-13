module BackgrounDRb
  class MasterProxy
    attr_accessor :reloadable_workers,:worker_triggers,:reactor
    def initialize
      raise "Running old Ruby version, upgrade to Ruby >= 1.8.5" unless check_for_ruby_version

      log_flag = BDRB_CONFIG[:backgroundrb][:debug_log].nil? ? true : BDRB_CONFIG[:backgroundrb][:debug_log]
      debug_logger = DebugMaster.new(BDRB_CONFIG[:backgroundrb][:log],log_flag)

      load_rails_env

      find_reloadable_worker

      Packet::Reactor.run do |t_reactor|
        @reactor = t_reactor
        t_reactor.start_worker(:worker => :log_worker,:worker_env => false) if log_flag
        t_reactor.start_server(BDRB_CONFIG[:backgroundrb][:ip],
                               BDRB_CONFIG[:backgroundrb][:port],MasterWorker) do |conn|
          conn.debug_logger = debug_logger
        end
        t_reactor.next_turn { reload_workers }
      end
    end

    # FIXME: Method by same name exists in Packet::NbioHelper module
    def gen_worker_key(worker_name,worker_key = nil)
      return worker_name if worker_key.nil?
      return "#{worker_name}_#{worker_key}".to_sym
    end


    # method should find reloadable workers and load their schedule from config file
    def find_reloadable_worker
      t_workers = Dir["#{WORKER_ROOT}/**/*.rb"]
      @reloadable_workers = t_workers.map do |x|
        worker_name = File.basename(x,".rb")
        require worker_name
        worker_klass = Object.const_get(worker_name.classify)
        worker_klass.reload_flag ? worker_klass : nil
      end.compact
      @worker_triggers = { }
      @reloadable_workers.each do |t_worker|
        schedule = load_reloadable_schedule(t_worker)
        if schedule && !schedule.empty?
          @worker_triggers[t_worker.worker_name.to_sym] = schedule
        end
      end
    end

    # load schedule of workers which should be restarted on schedule
    def load_reloadable_schedule(t_worker)
      worker_method_triggers = { }
      all_schedules = BDRB_CONFIG[:schedules]
      return if all_schedules.nil? or all_schedules.empty?
      worker_schedule = all_schedules[t_worker.worker_name.to_sym]

      worker_schedule && worker_schedule.each do |key,value|
        case value[:trigger_args]
        when String
          cron_args = value[:trigger_args] || "0 0 0 0 0"
          trigger = BackgrounDRb::CronTrigger.new(cron_args)
          worker_method_triggers[key] = {
            :trigger => trigger,:data => value[:data],
            :runtime => trigger.fire_after_time(Time.now).to_i
          }
        when Hash
          trigger = BackgrounDRb::Trigger.new(value[:trigger_args])
          worker_method_triggers[key] = {
            :trigger => trigger,:data => value[:trigger_args][:data],
            :runtime => trigger.fire_after_time(Time.now).to_i
          }
        end
      end
      worker_method_triggers
    end

    # Start the workers whose schedule has come
    def reload_workers
      return if worker_triggers.empty?
      worker_triggers.each do |key,value|
        value.delete_if { |key,value| value[:trigger].respond_to?(:end_time) && value[:trigger].end_time <= Time.now }
      end

      worker_triggers.each do |worker_name,trigger|
        trigger.each do |key,value|
          time_now = Time.now.to_i
          if value[:runtime] < time_now
            load_and_invoke(worker_name,key,value)
            t_time = value[:trigger].fire_after_time(Time.now)
            value[:runtime] = t_time.to_i
          end
        end
      end
    end

    # method will load the worker and invoke worker method
    def load_and_invoke(worker_name,p_method,data)
      begin
        require worker_name.to_s
        worker_key = Packet::Guid.hexdigest
        @reactor.start_worker(:worker => worker_name,:worker_key => worker_key,:disable_log => true)
        worker_name_key = gen_worker_key(worker_name,worker_key)
        data_request = {:data => { :worker_method => p_method,:arg => data[:data]},
          :type => :request, :result => false
        }

        exit_request = {:data => { :worker_method => :exit},
          :type => :request, :result => false
        }
        t_worker = @reactor.live_workers[worker_name_key]
        if t_worker
          t_worker.send_request(data_request)
          t_worker.send_request(exit_request)
        end
      rescue LoadError => e
        puts "no such worker #{worker_name}"
        puts e.backtrace.join("\n")
      rescue MissingSourceFile => e
        puts "no such worker #{worker_name}"
        puts e.backtrace.join("\n")
        return
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

    def check_for_ruby_version; RUBY_VERSION >= "1.8.5"; end
  end # end of module BackgrounDRb
end

