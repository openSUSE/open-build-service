desc('Write configuration to the backend now')
task(writeconfiguration: :environment) { ::Configuration.first.write_to_backend }

desc('Update all package meta now')
task(updatepackagemeta: :environment) { UpdatePackageMetaJob.new.perform }

desc('Import all requests from the backend now')
task(importrequests: :environment) do
  lastrq = Backend::Api::Request.last_id
  while lastrq.positive?
    begin
      xml = Backend::Api::Request.info(lastrq)
    rescue Backend::Error => e
      Rails.logger.error "Request ##{lastrq} could not be retrieved:\n#{e}"
      lastrq -= 1
      next
    end
    r = BsRequest.new_from_xml(xml)
    begin
      if r.save
        Rails.logger.info "Request ##{lastrq} imported"
      else
        Rails.logger.error format("Request ##{lastrq} could not be saved:\n%<error>s", error: r.errors.full_messages.join("\n"))
      end
    rescue ActiveRecord::RecordNotUnique
      Rails.logger.debug { "Request ##{lastrq} already imported" }
    end
    lastrq -= 1
  end
end

namespace :consistency do
  # basic argument check for check_project and fix_project tasks
  task(project_environment: :environment) do
    unless ENV['project']
      puts "Please specify the project with 'project=MyProject' on CLI"
      exit 1
    end
  end

  desc('Check project for consistency now, specify project with: project=MyProject')
  task(check: [:environment, :project_environment]) do
    puts ConsistencyCheckJob.new.check_project(ENV['project'])
  end

  desc('Fix inconsitent projects now, specify project with: project=MyProject')
  task(fix: [:environment, :project_environment]) do
    ConsistencyCheckJob.new.fix_project(ENV['project'])
  end
end

desc('Check project for consitency now, specify project with: project=MyProject')
task(check_project: :environment) { Old::ConsistencyCheckJob.new.check_project }

desc('Fix inconsitent projects now, specify project with: project=MyProject')
task(fix_project: :environment) { Old::ConsistencyCheckJob.new.fix_project }

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
