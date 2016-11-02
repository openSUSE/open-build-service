require 'workers/import_requests.rb'
require 'workers/update_issues.rb'

namespace :jobs do
  desc "Inject a job to write issue tracker information to backend"
  task(issuetrackers: :environment) { IssueTracker.write_to_backend }

  desc "Update issue data of all changed issues in remote tracker"
  task(updateissues: :environment) {
    IssueTracker.all.each do |t|
      next unless t.enable_fetch
      t.update_issues
    end
  }

  desc "Update issue data of ALL issues now"
  task(enforceissuesupdate: :environment) {
    IssueTracker.all.each do |t|
      next unless t.enable_fetch
      t.enforced_update_all_issues
    end
  }
end
