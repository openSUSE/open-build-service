require File.join(File.dirname(__FILE__) + "/../bdrb_test_helper")
require File.join(File.dirname(__FILE__) + "/../bdrb_client_test_helper")

context "For client helper" do
  specify "should return correct worker key" do
    class Foo
      include BackgrounDRb::ClientHelper
    end
    a = Foo.new
    a.gen_worker_key("hello","world").should == :hello_world
    a.gen_worker_key("hello").should == :hello
  end
end
