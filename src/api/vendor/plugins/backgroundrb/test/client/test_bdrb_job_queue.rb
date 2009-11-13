require File.join(File.dirname(__FILE__) + "/../bdrb_test_helper")
require File.join(File.dirname(__FILE__) + "/../bdrb_client_test_helper")
require "bdrb_job_queue"

context "For BackgrounDRb job Queues" do
  setup do
    db_config_file = YAML.load(ERB.new(IO.read("#{RAILS_HOME}/config/database.yml")).result)
    ActiveRecord::Base.establish_connection(db_config_file["test"])
    BdrbJobQueue.destroy_all
  end

  specify "should insert job with proper params" do
    BdrbJobQueue.insert_job(:worker_name => "hello_world",:worker_method => "foovar",:job_key => "cats",:args => "hello_world",:scheduled_at => Time.now.utc)
    next_job = BdrbJobQueue.find_next("hello_world")
    next_job.taken.should == 1
    next_job.started_at.should.not.be nil
    next_job.job_key.should == "cats"
    next_job.worker_name.should == "hello_world"
    next_job.worker_method.should == "foovar"
  end

  specify "should respect job priority" do

    BdrbJobQueue.insert_job(:priority => 4, :worker_name => "hello_world",:worker_method => "foovar",:job_key => "4",:args => "priority 4", :scheduled_at => Time.now.utc)
    BdrbJobQueue.insert_job(:priority => 1, :worker_name => "hello_world",:worker_method => "foovar",:job_key => "1",:args => "priority 1", :scheduled_at => Time.now.utc)
    BdrbJobQueue.insert_job(:priority => 10, :worker_name => "hello_world",:worker_method => "foovar",:job_key => "10",:args => "priority 10", :scheduled_at => Time.now.utc)

    [10,4,1].each do |priority|      
      next_job = BdrbJobQueue.find_next("hello_world")
      next_job.taken.should == 1
      next_job.started_at.should.not.be nil
      next_job.job_key.should == priority.to_s
      next_job.worker_name.should == "hello_world"
      next_job.worker_method.should == "foovar"
      next_job.priority.should == priority
    end
  end

  specify "release_job should worker properly" do
    BdrbJobQueue.insert_job(:worker_name => "hello_world",:worker_method => "foovar",:job_key => "cats",:args => "hello_world",:scheduled_at => Time.now.utc)
    next_job = BdrbJobQueue.find_next("hello_world")
    next_job.release_job
    t = BdrbJobQueue.find_by_job_key("cats")
    t.taken.should == 0
    t.started_at.should == nil
  end

  specify "remove job should work properly" do
    BdrbJobQueue.insert_job(:worker_name => "hello_world",:worker_method => "foovar",:job_key => "cats",:args => "hello_world",:scheduled_at => Time.now.utc)
    BdrbJobQueue.remove_job(:worker_name => "hello_world",:worker_method => "foovar",:job_key => "cats")
    t = BdrbJobQueue.find_by_job_key("cats")
    t.should == nil
  end

  specify "finish should work properly" do
    BdrbJobQueue.insert_job(:worker_name => "hello_world",:worker_method => "foovar",:job_key => "cats",:args => "hello_world",:scheduled_at => Time.now.utc)
    t = BdrbJobQueue.find_next("hello_world")
    t.finish!
    t.finished.should == 1
    t.finished_at.should.not == nil
    t.job_key.should.match(/finished_\d+_cats/i)
  end
end
