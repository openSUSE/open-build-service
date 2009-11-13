require File.join(File.dirname(__FILE__) + "/../socket_mocker")
require File.join(File.dirname(__FILE__) + "/../bdrb_test_helper")
require File.join(File.dirname(__FILE__) + "/../bdrb_client_test_helper")

context "For Actual BackgrounDRB connection" do
  setup do
    options = {:schedules => {
        :foo_worker => { :barbar=>{:trigger_args=>"*/5 * * * * * *"}}},
      :backgroundrb=>{:port=>11008, :ip=>"0.0.0.0", :environment=> "production"},
      :client => "localhost:11001,localhost:11002,localhost:11003"
    }
    BDRB_CONFIG.set(options)
    @cluster = mock()
    @foo_connection = BackgrounDRb::Connection.new('localhost',1267,"crap")
    @foo_connection.stubs(:close_connection)
    class << @foo_connection
      attr_accessor :outgoing_data
      def dump_object data
        @outgoing_data = data
      end
    end
  end

  specify "should return nil if ask_result returns nil" do
    a = @foo_connection.ask_result(:worker => 'foo_worker',:worker_key => 'bar',:job_key => 10)
    a.should == nil
    @foo_connection.outgoing_data.should == {:type=>:get_result, :job_key=>10, :worker=>"foo_worker", :worker_key=>"bar"}
  end
end
