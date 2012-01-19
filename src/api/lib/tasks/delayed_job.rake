require 'workers/status_monitor_job.rb'
require 'workers/issue_trackers_to_backend_job.rb'

namespace :jobs do
  desc "Inject a job to update the workerstatus cache"
  task(:workerstatus => :environment) { Delayed::Job.enqueue StatusMonitorJob.new }
end

namespace :jobs do
  desc "Inject a job to write issue tracker information to backend"
  task(:issuetrackers => :environment) { Delayed::Job.enqueue IssueTrackersToBackendJob.new }
end

