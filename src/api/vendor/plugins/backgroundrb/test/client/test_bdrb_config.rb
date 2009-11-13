require File.join(File.dirname(__FILE__) + "/../bdrb_test_helper")
require File.join(File.dirname(__FILE__) + "/../bdrb_client_test_helper")

context "For BackgrounDRb config" do
  conf_file = File.join(File.dirname(__FILE__),"backgroundrb.yml")
  specify "should setup correct environment from cmd options" do
    BackgrounDRb::Config.parse_cmd_options(["-e", "production"])
    BackgrounDRb::Config.read_config(conf_file)
    ENV["RAILS_ENV"].should == "production"
    RAILS_ENV.should == "production"
  end

  specify "should setup correct environment from conf file" do
    ENV["RAILS_ENV"] = nil
    BackgrounDRb::Config.parse_cmd_options([])
    BackgrounDRb::Config.read_config(conf_file)
    ENV["RAILS_ENV"].should == "development"
    RAILS_ENV.should == "development"
  end
end
