require File.join(File.dirname(__FILE__) + "/../bdrb_test_helper")
require "god_worker"

context "When god worker starts" do
  setup do
    god_worker = GodWorker.new
  end
end
