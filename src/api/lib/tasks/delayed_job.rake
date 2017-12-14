desc 'Write configuration to the backend now'
task(writeconfiguration: :environment) { ::Configuration.first.write_to_backend }

desc 'Update all package meta now'
task(updatepackagemeta: :environment) { UpdatePackageMetaJob.new.perform }

desc "Import all requests from the backend now"
task(importrequests: :environment) do
  lastrq = Backend::Connection.get("/request/_lastid").body.to_i
  while lastrq > 0
    begin
      xml = Backend::Connection.get("/request/#{lastrq}").body
    rescue ActiveXML::Transport::Error
      lastrq -= 1
      next
    end
    r = BsRequest.new_from_xml xml
    unless r.save
      puts "Request ##{lastrq}:", r.errors.full_messages.join("\n")
    end
    lastrq -= 1
  end
end

desc 'Check project for consitency now, specify project with: project=MyProject'
task(check_project: :environment) { ConsistencyCheckJob.new.check_project }

desc 'Fix inconsitent projects now, specify project with: project=MyProject'
task(fix_project: :environment) { ConsistencyCheckJob.new.fix_project }

namespace :jobs do
  desc "Inject a job to write issue tracker information to backend"
  task(issuetrackers: :environment) { IssueTracker.first.try(:save!) }

  desc 'Update all changed issues from remote IssueTrackers now'
  task(updateissues: :environment) {
    IssueTracker.all.each do |t|
      next unless t.enable_fetch
      t.update_issues
    end
  }

  desc 'Import all issues from remote IssueTrackers now'
  task(enforceissuesupdate: :environment) {
    IssueTracker.all.each do |t|
      next unless t.enable_fetch
      t.enforced_update_all_issues
    end
  }
end
