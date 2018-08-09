desc('Write configuration to the backend now')
task(writeconfiguration: :environment) { ::Configuration.first.write_to_backend }

desc('Update all package meta now')
task(updatepackagemeta: :environment) { UpdatePackageMetaJob.new.perform }

desc('Import all requests from the backend now')
task(importrequests: :environment) do
  lastrq = Backend::Api::Request.last_id
  while lastrq > 0
    begin
      xml = Backend::Api::Request.info(lastrq)
    rescue ActiveXML::Transport::Error
      lastrq -= 1
      next
    end
    r = BsRequest.new_from_xml(xml)
    puts "Request ##{lastrq}:", r.errors.full_messages.join("\n") unless r.save
    lastrq -= 1
  end
end

desc('Check project for consitency now, specify project with: project=MyProject')
task(check_project: :environment) { ConsistencyCheckJob.new.check_project }

desc('Fix inconsitent projects now, specify project with: project=MyProject')
task(fix_project: :environment) { ConsistencyCheckJob.new.fix_project }

namespace :jobs do
  desc 'Inject a job to write issue tracker information to backend'
  task(issuetrackers: :environment) { IssueTracker.first.try(:save!) }

  desc 'Update all changed issues from remote IssueTrackers now'
  task(updateissues: :environment) do
    IssueTracker.all.each do |t|
      next unless t.enable_fetch
      t.update_issues
    end
  end

  desc 'Import all issues from remote IssueTrackers now'
  task(enforceissuesupdate: :environment) do
    IssueTracker.all.each do |t|
      next unless t.enable_fetch
      t.enforced_update_all_issues
    end
  end
end
