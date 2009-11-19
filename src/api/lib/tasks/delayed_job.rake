require 'workers/status_monitor_job.rb'

namespace :jobs do
  desc "Inject a job to update the workerstatus cache"
  task(:workerstatus => :environment) { Delayed::Job.enqueue StatusMonitorJob.new }

end
