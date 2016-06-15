require "spec_helper"

RSpec.describe "Basic Setup for appliance tests" do

  it "should be able to reconfigure worker" do
    file_name = "/etc/sysconfig/obs-server"
    text = File.read(file_name)
    new_contents = text.gsub(/OBS_WORKER_INSTANCES=.*/, "OBS_WORKER_INSTANCES=1")
    File.open(file_name, "w") {|file| file.puts new_contents }
    system("/etc/init.d/obsworker stop")
    system("/etc/init.d/obsworker start")
  end

end
