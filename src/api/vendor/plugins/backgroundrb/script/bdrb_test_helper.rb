require File.join(File.dirname(__FILE__) + "/../config/environment")
WORKER_ROOT = RAILS_ROOT + "/lib/workers"
$LOAD_PATH.unshift(WORKER_ROOT)

class Object
  def self.metaclass; class << self; self; end; end

  def self.iattr_accessor *args
    metaclass.instance_eval do
      attr_accessor *args
      args.each do |attr|
        define_method("set_#{attr}") do |b_value|
          self.send("#{attr}=",b_value)
        end
      end
    end

    args.each do |attr|
      class_eval do
        define_method(attr) do
          self.class.send(attr)
        end
        define_method("#{attr}=") do |b_value|
          self.class.send("#{attr}=",b_value)
        end
      end
    end
  end
end

module BackgrounDRb
  class WorkerDummyLogger
    %w(info debug fatal error warn).each do |x|
      define_method(x) do |log_data|
      end
    end
  end

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

    def initialize(master,size)
      @master = master
      @logger = logger
      @size = size
      @threads = []
    end

    def defer(method_name,args = nil)
      job_key = Thread.current[:job_key]
      persistent_job_id = Thread.current[:persistent_job_id]
      t = WorkData.new(args,job_key,method_name,persistent_job_id)
      result = run_task(t)
      result
    end

    # run tasks popped out of queue
    def run_task task
      block_arity = master.method(task.job_method).arity
      begin
        t_data = task.args
        result = nil
        if block_arity != 0
          result = master.send(task.job_method,task.args)
        else
          result = master.send(task.job_method)
        end
        return result
      rescue
        puts($!.to_s)
        puts($!.backtrace.join("\n"))
        return nil
      end
    end
  end #end of class ThreadPool

  class MetaWorker
    attr_accessor :logger,:thread_pool
    iattr_accessor :worker_name
    iattr_accessor :no_auto_load

    def initialize
      @logger = WorkerDummyLogger.new
      @thread_pool = ThreadPool.new(self,10)
    end
  end
end

