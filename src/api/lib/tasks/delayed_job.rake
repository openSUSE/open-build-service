require 'workers/issue_trackers_to_backend_job.rb'

namespace :jobs do
  desc "Inject a job to update the workerstatus cache"
  task(:workerstatus => :environment) do
     c = StatusController.new
     c.update_workerstatus_cache
  end

  desc "Inject a job to write issue tracker information to backend"
  task(:issuetrackers => :environment) { Delayed::Job.enqueue IssueTrackersToBackendJob.new }

  desc "Update issue data of all changed issues in remote tracker"
  task(:updateissues => :environment) {
    IssueTracker.all.each do |t|
      next unless t.enable_fetch
      t.update_issues
    end
  }

  desc "Update issue data of ALL issues now"
  task(:enforceissuesupdate => :environment) {
    IssueTracker.all.each do |t|
      next unless t.enable_fetch
      t.enforced_update_all_issues
    end
  }
end

