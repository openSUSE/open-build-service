require File.join(File.dirname(__FILE__) + "/..","bdrb_test_helper")

context "Result storage" do
  setup do
    @cache = BackgrounDRb::ResultStorage.new(:some_worker,:crap)
  end

  specify "should store result" do
    @cache[:foo] = "Wow"
    @cache[:foo].should == "Wow"
    @cache.delete(:foo)
    @cache[:foo].should == nil
  end
end
