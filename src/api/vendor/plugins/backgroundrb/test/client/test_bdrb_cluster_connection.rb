require File.join(File.dirname(__FILE__) + "/../bdrb_test_helper")
require File.join(File.dirname(__FILE__) + "/../bdrb_client_test_helper")

context "For Cluster connection" do
  class BackgrounDRb::Connection
    attr_accessor :server_ip,:server_port,:cluster_conn,:connection_status
    def establish_connection
      @connection_status = true
    end

    def close_connection
      @connection_status = false
    end
    def server_info; "#{@server_ip}:#{server_port}"; end
  end

  setup do
    BDRB_CONFIG.set({:schedules=> {
        :foo_worker => { :barbar=>{:trigger_args=>"*/5 * * * * * *"}}},
      :backgroundrb=>{:port=>11008, :ip=>"0.0.0.0", :environment=> "production"},
      :client => "localhost:11001,localhost:11002,localhost:11003"
    })

    @cluster_connection = BackgrounDRb::ClusterConnection.new
    class << @cluster_connection
      def ivar(var)
        return instance_variable_get("@#{var}")
      end
      def iset(var,value)
        instance_variable_set("@#{var}",value)
      end
    end
  end

  specify "should read config file and connect to specified servers" do
    @cluster_connection.backend_connections.length.should == 4
    @cluster_connection.bdrb_servers.length.should == 4
    @cluster_connection.ivar(:round_robin).length.should == 4
    @cluster_connection.backend_connections[0].server_info.should == "localhost:11001"
  end

  specify "should return worker chosen in round robin manner if nothing specified" do
    t_conn = @cluster_connection.choose_server
    t_conn.server_info.should == "localhost:11001"
    t_conn = @cluster_connection.choose_server
    t_conn.server_info.should == "localhost:11002"
  end

  specify "should return connection from chosen host if specified" do
    t_conn = @cluster_connection.find_connection("localhost:11001")
    t_conn.server_info.should == "localhost:11001"
  end

  specify "should return connection from local host if specified" do
    t_conn = @cluster_connection.find_local
    t_conn.server_info.should == "0.0.0.0:11008"
  end

  specify "should not return disconnected connections" do
    t_conn = @cluster_connection.find_next_except_these(Array("localhost:11001"))
    @cluster_connection.ivar(:disconnected_connections).size.should == 1
    @cluster_connection.backend_connections.size.should == 3
    server_infos = @cluster_connection.backend_connections.map(&:server_info)
    server_infos.should.include "0.0.0.0:11008"
    server_infos.should.include "localhost:11002"
    server_infos.should.include "localhost:11003"
    server_infos.should.not.include "localhost:11001"
    t_conn.server_info.should.not == "localhost:11001"
  end

  specify "should discover new connections when time to discover" do
    t_conn = @cluster_connection.find_next_except_these(Array("localhost:11001"))
    @cluster_connection.ivar(:disconnected_connections).size.should == 1
    @cluster_connection.backend_connections.size.should == 3
    @cluster_connection.iset(:request_count,9)
    worker_proxy = @cluster_connection.worker(:hello_worker)
    @cluster_connection.ivar(:disconnected_connections).size.should == 0
    @cluster_connection.backend_connections.size.should == 4
  end

  specify "discover service should run only when connections were dropped" do
    @cluster_connection.iset(:request_count,9)
    @cluster_connection.expects(:disover_periodically).never
    worker_proxy = @cluster_connection.worker(:hello_worker)
  end

  specify "should work with new_worker method calls" do
    @cluster_connection.backend_connections.each do |t_conn|
      t_conn.expects(:new_worker).with(:worker => :hello_worker,:worker_key => "boy",:data => "boy").returns(true)
    end
    a = @cluster_connection.new_worker(:worker => :hello_worker,:worker_key => "boy",:data => "boy")
    a.should == "boy"
  end

  specify "should work with all worker info methods" do
    @cluster_connection.backend_connections.each do |t_conn|
      t_conn.expects(:all_worker_info).returns(:status => :running)
    end
    foo = @cluster_connection.all_worker_info
    foo.should == {"0.0.0.0:11008"=>{:status=>:running}, "localhost:11001"=>{:status=>:running}, "localhost:11002"=>{:status=>:running}, "localhost:11003"=>{:status=>:running}}
  end
end

context "For single connections" do
  class BackgrounDRb::Connection
    attr_accessor :server_ip,:server_port,:cluster_conn,:connection_status
  end

  setup do
    BDRB_CONFIG.set({:schedules=> {
        :foo_worker => { :barbar=>{:trigger_args=>"*/5 * * * * * *"}}},
      :backgroundrb=>{:port=>11008, :ip=>"0.0.0.0", :environment=> "production"}
    })

    @cluster_connection = BackgrounDRb::ClusterConnection.new
    class << @cluster_connection
      def ivar(var)
        return instance_variable_get("@#{var}")
      end
    end
  end

  specify "should read config file and connect to servers" do
    @cluster_connection.backend_connections.length.should == 1
    @cluster_connection.bdrb_servers.length.should == 1
    @cluster_connection.ivar(:round_robin).length.should == 1
    @cluster_connection.backend_connections[0].server_info.should == "0.0.0.0:11008"
  end
end

context "For memcache based result storage" do
  setup do
    options = { :schedules =>
      {
        :foo_worker => { :barbar=>{:trigger_args=>"*/5 * * * * * *"}}
      },
      :backgroundrb =>
      {
        :port=>11008, :ip=>"0.0.0.0", :environment=> "production",:result_storage => 'memcache'
      },
      :client => "localhost:11001,localhost:11002,localhost:11003",
      :memcache => "10.0.0.1:11211,10.0.0.2:11211"
    }
    BDRB_CONFIG.set(options)

    @cluster_connection = BackgrounDRb::ClusterConnection.new
    class << @cluster_connection
      def ivar(var)
        return instance_variable_get("@#{var}")
      end
      def iset(var,value)
        instance_variable_set("@#{var}",value)
      end
    end
  end


  specify "should use memcache based result storage if specified" do
    @cluster_connection.cache.should.not == nil
    @cluster_connection.cache.class.should == MemCache
  end
end
