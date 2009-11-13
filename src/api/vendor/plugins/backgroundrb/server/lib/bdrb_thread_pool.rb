module BackgrounDRb

  class InterruptedException < RuntimeError ; end

  class WorkData
    attr_accessor :args,:block,:job_method,:persistent_job_id,:job_key
    def initialize(args,job_key,job_method,persistent_job_id)
      @args = args
      @job_key = job_key
      @job_method = job_method
      @persistent_job_id = persistent_job_id
    end
  end

  class ThreadPool
    attr_accessor :size,:threads,:work_queue,:logger
    attr_accessor :result_queue,:master

    def initialize(master,size,logger)
      @master = master
      @logger = logger
      @size = size
      @threads = []
      @work_queue = []
      @mutex = Monitor.new
      @cv = @mutex.new_cond
      @size.times { add_thread }
    end

    # can be used to make a call in threaded manner
    # passed block runs in a thread from thread pool
    # for example in a worker method you can do:
    #   def user_tags url
    #     thread_pool.defer(:fetch_url,url)
    #   end
    #   def fetch_url(url)
    #     begin
    #       data = Net::HTTP.get(url,'/')
    #       File.open("#{RAILS_ROOT}/log/pages.txt","w") do |fl|
    #         fl.puts(data)
    #       end
    #     rescue
    #       logger.info "Error downloading page"
    #     end
    #   end
    # you can invoke above method from rails as:
    #   MiddleMan.worker(:rss_worker).async_user_tags(:arg => "en.wikipedia.org")
    # assuming method is defined in rss_worker

    def defer(method_name,args = nil)
      @mutex.synchronize do
        job_key = Thread.current[:job_key]
        persistent_job_id = Thread.current[:persistent_job_id]
        @cv.wait_while { @work_queue.size >= size }
        @work_queue.push(WorkData.new(args,job_key,method_name,persistent_job_id))
        @cv.broadcast
      end
    end

    # Start worker threads
    def add_thread
      @threads << Thread.new do
        Thread.current[:job_key] = nil
        Thread.current[:persistent_job_id] = nil
        while true
          begin
            task = nil
            @mutex.synchronize do
              @cv.wait_while { @work_queue.size == 0 }
              task = @work_queue.pop
              @cv.broadcast
            end
            if task
              Thread.current[:job_key] = task.job_key
              Thread.current[:persistent_job_id] = task.persistent_job_id
              block_result = run_task(task)
            end
          rescue BackgrounDRb::InterruptedException
            STDERR.puts("BackgrounDRb thread interrupted: #{Thread.current.inspect}")
            STDERR.flush
          end
        end
      end
    end

    # run tasks popped out of queue
    def run_task task
      block_arity = master.method(task.job_method).arity
      begin
        check_db_connection
        t_data = task.args
        result = nil
        if block_arity != 0
          result = master.send(task.job_method,task.args)
        else
          result = master.send(task.job_method)
        end
        return result
      rescue BackgrounDRb::InterruptedException => e
        # Don't log, just re-raise
        raise e
      rescue Object => bdrb_error
        log_exception(bdrb_error)
        return nil
      end
    end

    def log_exception exception_object
      STDERR.puts exception_object.to_s
      STDERR.puts exception_object.backtrace.join("\n")
      STDERR.flush
    end


    # Periodic check for lost database connections and closed connections
    def check_db_connection
      begin
        ActiveRecord::Base.verify_active_connections! if defined?(ActiveRecord)
      rescue Object => bdrb_error
        log_exception(bdrb_error)
      end
    end


  end #end of class ThreadPool
end # end of module BackgrounDRb

