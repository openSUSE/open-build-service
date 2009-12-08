require 'net/smtp'

set :application, "obs-api"

# git settings
set :scm, :git
set :repository,  "git://gitorious.org/opensuse/build-service.git"
set :branch, "master"
set :deploy_via, :remote_cache
set :git_enable_submodules, 1
set :git_subdir, '/src/api'

set :deploy_notification_to, ['tschmidt@suse.de', 'coolo@suse.de', 'adrian@suse.de']
server "buildserviceapi.suse.de", :app, :web, :db, :primary => true

# If you aren't deploying to /u/apps/#{application} on the target
# servers (which is the default), you can specify the actual location
# via the :deploy_to variable:
set :deploy_to, "/srv/www/vhosts/opensuse.org/#{application}"

# set variables for different target deployments
task :stage do
  set :deploy_to, "/srv/www/vhosts/opensuse.org/stage/#{application}"
end
task :ibs do

end


ssh_options[:forward_agent] = true
default_run_options[:pty] = true
set :normalize_asset_timestamps, false

# tasks are run with this user
set :user, "root"
# spinner is run with this user
set :runner, "root"

after "deploy:update_code", "config:symlink_shared_config"
after "deploy:symlink", "config:permissions"

# workaround because we are using a subdirectory of the git repo as rails root
before "deploy:finalize_update", "deploy:use_subdir"
after "deploy:finalize_update", "deploy:reset_subdir"
after "deploy:finalize_update", "deploy:notify"

after :deploy, 'deploy:cleanup' # only keep 5 releases


namespace :config do

  desc "Install saved configs from /shared/ dir"
  task :symlink_shared_config do
    run "rm #{release_path}#{git_subdir}/config/database.yml"
    run "ln -s #{shared_path}/database.yml #{release_path}#{git_subdir}/config/"
    run 'HERMESPWD=$(cat #{shared_path}/HERMESPWD); sed -e ",hermesconf.dbpass.*,hermesconf.dbpass = $HERMESPWD," #{release_path}#{git_subdir}/config/environments/production.rb'
  end

  desc "Set permissions"
  task :permissions do
    run "chown -R lighttpd #{current_path}#{git_subdir}/tmp"
  end
end

# server restarting
namespace :deploy do
  task :start do
    run "sv start /service/frontend-*"
    run "sv start /service/delayed_job_frontend"
  end

  task :restart do
    run "sv 1 /service/frontend-*"
    run "sv restart /service/delayed_job_frontend"
  end

  task :stop do
    run "sv stop /service/frontend-*"
    run "sv stop /service/delayed_job_frontend"
  end

  task :use_subdir do
    set :latest_release_bak, latest_release
    set :latest_release, "#{latest_release}#{git_subdir}"
  end

  task :reset_subdir do
    set :latest_release, latest_release_bak
  end


  desc "Send email notification of deployment"
  task :notify do
    #diff = `#{source.local.diff(current_revision)}`
    diff_log = `#{source.local.log( source.next_revision(current_revision) )}`
    user = `whoami`
    body = %Q[From: obs-api-deploy@suse.de
To: #{deploy_notification_to.join(", ")}
Subject: obs-api deployed by #{user}

Git log:
#{diff_log}]

    Net::SMTP.start('relay.suse.de', 25) do |smtp|
      smtp.send_message body, 'obs-api-deploy@suse.de', deploy_notification_to
    end
  end
  
end


