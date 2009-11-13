require File.join(File.dirname(__FILE__) + "/../bdrb_test_helper")
require "meta_worker"
require "chronic"

context "A Meta Worker should" do
  module Kernel
    def packet_dump data
      t = Marshal.dump(data)
      t.length.to_s.rjust(9,'0') + t
    end
  end
  setup do
    options = {:schedules =>
      {
        :proper_worker => { :barbar => {:trigger_args=>"*/5 * * * * *", :data =>"Hello World" }},
        :bar_worker => { :do_job => {:trigger_args=>"*/5 * * * * *", :data =>"Hello World" }}
      },
      :backgroundrb => {:log => "foreground", :debug_log => false, :environment => "production", :port => 11006, :ip => "localhost"}
    }
    BDRB_CONFIG.set(options)

    BackgrounDRb::MetaWorker.worker_name = "hello_worker"

    class ProperWorker < BackgrounDRb::MetaWorker
      attr_accessor :outgoing_data
      attr_accessor :incoming_data
      set_worker_name :proper_worker
      def send_data(data)
        @outgoing_data = data
      end

      def start_reactor; end

      def ivar(var)
        instance_variable_get("@#{var}")
      end
    end
    @meta_worker = ProperWorker.start_worker
  end

  specify "load appropriate db environment from config file" do
    ENV["RAILS_ENV"] = BDRB_CONFIG[:backgroundrb][:environment]
    @meta_worker.send(:load_rails_env)
    ActiveRecord::Base.connection.current_database.should == "rails_sandbox_production"
  end


  specify "load appropriate schedule from config file" do
    @meta_worker.my_schedule.should.not == nil
    @meta_worker.my_schedule.should == {:barbar=>{:data=>"Hello World", :trigger_args=>"*/5 * * * * *"}}
    trigger = @meta_worker.ivar(:worker_method_triggers)
    trigger.should.not == nil
    trigger[:barbar][:data].should == "Hello World"
  end

  specify "should load passed data and invoke methods" do
    a = {:data=>{:worker_method=>"who", :arg=>"rails"}, :type=>:request, :result=>false, :client_signature=>9}
    b = {:data=>{:worker_method=>"baz", :arg=>"rails"}, :type=>:request, :result=>true, :client_signature=>9}
    c = {:data=>{:job_key=>:start_message}, :type=>:get_result, :result=>true, :client_signature=>9}
    t_request = "000000088\004\b{\t:\ttype:\frequest:\025client_signaturei\016:\vresultF:\tdata{\a:\022worker_method\"\bwho:\barg\"\nrails"
    @meta_worker.expects(:receive_data).with(a).returns(nil)
    @meta_worker.receive_internal_data(t_request)
  end

  specify "should invoke async tasks without sending results" do
    a = {:data=>{:worker_method=>"who", :arg=>"rails",:job_key => "lol"}, :type=>:request, :result=>false, :client_signature=>9}
    @meta_worker.expects(:who).with("rails").returns(nil)
    @meta_worker.receive_internal_data(packet_dump(a))
    Thread.current[:job_key].should == "lol"
  end

  specify "should invoke sync methods and return results back" do
    class << @meta_worker
      def baz args
        "hello : #{args}"
      end
    end
    b = {:data=>{:worker_method=>"baz", :arg=>"rails"}, :type=>:request, :result=>true, :client_signature=>9}
    @meta_worker.expects(:send_data).with({:data=>"hello : rails", :type=>:response, :result=>true, :client_signature=>9, :result_flag => "ok"}).returns("hello : rails")
    @meta_worker.receive_internal_data(packet_dump(b))
    Thread.current[:job_key].should == nil
  end

  specify "should invoke methods with and without args correctly" do
    class << @meta_worker
      attr_accessor :outgoing_data
      def send_data data
        @outgoing_data = data
      end
    end
    b = {:data=> {:worker_method=>"baz", :arg => { :name => "bdrb",:age => 10} }, :type=>:request, :result=>true, :client_signature=>9 }
    # @meta_worker.expects(:send_data).with({:data=>"hello : rails", :type=>:response, :result=>true, :client_signature=>9}).returns("hello : rails")
    @meta_worker.expects(:baz).with({ :name => "bdrb",:age => 10}).returns("foo")
    @meta_worker.receive_internal_data(packet_dump(b))
    @meta_worker.outgoing_data[:data].should == "foo"
    Thread.current[:job_key].should == nil
  end

  specify "for result request" do
    class << @meta_worker
      attr_accessor :t_result
      def send_data data
        @t_result = data
      end
    end
    @meta_worker.cache[:start_message] = "helloworld"
    c = {:data=>{:job_key=>:start_message}, :type=>:get_result, :result=>true, :client_signature=>9}
    @meta_worker.receive_internal_data(packet_dump(c))
    @meta_worker.t_result[:data].should == "helloworld"
  end

  specify "for results that cant be dumped" do
    class << @meta_worker
      def baz args
        proc { "boy"}
      end
      def send_data input
        packet_dump(input)
      end
    end
    b = {:data=>{:worker_method=>"baz", :arg=>"rails"}, :type=>:request, :result=>true, :client_signature=>9}
    a = @meta_worker.receive_internal_data(packet_dump(b))
    p a
    Thread.current[:job_key].should == nil
  end
end

context "For unix schedulers" do
  specify "remove a task from schedule if end time is reached" do
    options = {:schedules =>
      {
        :unix_worker => { :barbar => { :trigger_args =>
            {
              :start => (Time.now + 2.seconds).to_s,
              :end => (Time.now + 10.seconds).to_s,
              :repeat_interval => 2.seconds,
              :data => "unix_worker"
            }
          }
        },
      },
      :backgroundrb =>
      {
        :log => "foreground", :debug_log => false, :environment => "production", :port => 11006, :ip => "localhost"
      }
    }
    BDRB_CONFIG.set(options)

    class UnixWorker < BackgrounDRb::MetaWorker
      attr_accessor :outgoing_data
      attr_accessor :incoming_data
      set_worker_name :unix_worker
      def send_data(data)
        @outgoing_data = data
      end

      def start_reactor; end

      def ivar(var)
        instance_variable_get("@#{var}")
      end
    end
    @meta_worker = UnixWorker.start_worker
    @meta_worker.my_schedule.should.not == nil
    @meta_worker.ivar(:worker_method_triggers).should.not == nil
    @meta_worker.ivar(:worker_method_triggers)[:barbar].should.not == nil
  end
end

context "Worker without names" do
  specify "should throw an error on initialization" do
    options = {:schedules =>
      {
        :foo_worker => { :barbar => {:trigger_args=>"*/5 * * * * *", :data =>"Hello World" }},
        :bar_worker => { :do_job => {:trigger_args=>"*/5 * * * * *", :data =>"Hello World" }}
      },
      :backgroundrb => {:log => "foreground", :debug_log => false, :environment => "production", :port => 11006, :ip => "localhost"}
    }
    BDRB_CONFIG.set(options)

    BackgrounDRb::MetaWorker.worker_name = "hello_worker"

    class BoyWorker < BackgrounDRb::MetaWorker
      attr_accessor :outgoing_data
      attr_accessor :incoming_data
      def send_data(data)
        @outgoing_data = data
      end

      def start_reactor; end
    end
    should.raise { @meta_worker = BoyWorker.start_worker }
  end
end

context "Worker with options" do
  specify "should load schedule from passed options" do
    options = { :backgroundrb => {:log => "foreground", :debug_log => false, :environment => "production", :port => 11006, :ip => "localhost"}}
    BDRB_CONFIG.set(options)

    BackgrounDRb::MetaWorker.worker_name = "hello_worker"

    class CrapWorker < BackgrounDRb::MetaWorker
      set_worker_name :crap_worker
      set_no_auto_load true
      attr_accessor :outgoing_data
      attr_accessor :incoming_data
      def send_data(data)
        @outgoing_data = data
      end

      def start_reactor; end
      def ivar(var); instance_variable_get("@#{var}"); end
    end
    write_end = mock()
    read_end = mock()
    worker_options = { :write_end => mock(),:read_end => mock(),
      :options => {
        :data => "hello", :schedule => {
          :hello_world => { :trigger_args => "*/5 * * * * * *",
            :data => "hello_world"
          }
        }
      }
    }
    CrapWorker.any_instance.expects(:create).with("hello").returns(true)
    @meta_worker = CrapWorker.start_worker(worker_options)
    @meta_worker.my_schedule.should == {:hello_world=>{:data=>"hello_world", :trigger_args=>"*/5 * * * * * *"}}
  end
end

context "For enqueued tasks" do
  setup do
    options = {:schedules =>
      {
        :proper_worker => { :barbar => {:trigger_args=>"*/5 * * * * *", :data =>"Hello World" }},
        :bar_worker => { :do_job => {:trigger_args=>"*/5 * * * * *", :data =>"Hello World" }}
      },
      :backgroundrb => {:log => "foreground", :debug_log => false, :environment => "production", :port => 11006, :ip => "localhost"}
    }
    BDRB_CONFIG.set(options)

    class BdrbJobQueue < ActiveRecord::Base; end
    class QueueWorker < BackgrounDRb::MetaWorker
      attr_accessor :outgoing_data
      attr_accessor :incoming_data
      set_worker_name :queue_worker
      def send_data(data)
        @outgoing_data = data
      end

      def start_reactor; end

      def ivar(var)
        instance_variable_get("@#{var}")
      end
    end
  end

  specify "should run enqueued tasks with arguments if they are there in the queue" do
    @meta_worker = QueueWorker.start_worker
    mocked_task = mock()
    mocked_task.expects(:worker_method).returns(:barbar).times(2)
    mocked_task.expects(:args).returns(Marshal.dump("hello"))
    mocked_task.expects(:[]).returns(1).times(2)
    @meta_worker.expects(:barbar).with("hello").returns(true)
    BdrbJobQueue.expects(:find_next).with("queue_worker").returns(mocked_task)
    @meta_worker.check_for_enqueued_tasks
  end

  specify "should run enqueued tasks without arguments if they are there in the queue" do
    @meta_worker = QueueWorker.start_worker
    mocked_task = mock()
    mocked_task.expects(:[]).returns(1).times(2)
    mocked_task.expects(:worker_method).returns(:barbar).times(2)
    mocked_task.expects(:args).returns(nil)
    @meta_worker.expects(:barbar)
    BdrbJobQueue.expects(:find_next).with("queue_worker").returns(mocked_task)
    @meta_worker.check_for_enqueued_tasks
  end
end
