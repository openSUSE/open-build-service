require 'net/smtp'

depend :local, :gem, 'capistrano', '>=2.11.2'

set :application, "obs-api"

# git settings
set :scm, :git
set :repository, "git://github.com/openSUSE/open-build-service.git"
set :branch, "2.3"
set :deploy_via, :remote_cache
set :git_enable_submodules, 1
set :git_subdir, '/src/api'
set :migrate_target, :current

set :deploy_notification_to, %w(tschmidt@suse.de coolo@suse.de adrian@suse.de saschpe@suse.de mls@suse.de)
server "buildserviceapi.suse.de", :app, :web, :db, primary: true

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
after "deploy:create_symlink", "config:permissions"

before "deploy:update_code", "deploy:test_suite"

# workaround because we are using a subdirectory of the git repo as rails root
before "deploy:finalize_update", "deploy:use_subdir"
after "deploy:finalize_update", "deploy:reset_subdir"
after "deploy:finalize_update", "deploy:notify"

after :deploy, 'deploy:cleanup' # only keep 5 releases

namespace :config do
  desc "Install saved configs from /shared/ dir"
  task :symlink_shared_config do
    run "ln -s #{shared_path}/options.yml #{release_path}#{git_subdir}/config/"
    run "ln -s #{shared_path}/secret.key #{release_path}#{git_subdir}/config/"
    run "ln -s #{shared_path}/database.yml #{release_path}#{git_subdir}/config/"
    run "ln -s #{shared_path}/distributions.xml #{release_path}#{git_subdir}/files"
    run "rm #{release_path}#{git_subdir}/config/environments/production.rb"
    run "ln -s #{shared_path}/production.rb #{release_path}#{git_subdir}/config/environments/production.rb"
    date=%x(date +%Y%m%d%H%M)
    run "sed -i 's,^API_DATE.*,API_DATE = \"#{date.chomp}\",' #{release_path}#{git_subdir}/config/environments/production.rb"
  end

  desc "Set permissions"
  task :permissions do
    run "chown -R apirun #{current_path}/tmp"
  end
end

# server restarting
namespace :deploy do
  task :restart do
    run "touch #{current_path}/tmp/restart.txt"
    run "/etc/init.d/obsapidelayed restart"
  end

  task :use_subdir do
    set :latest_release_bak, latest_release
    set :latest_release, "#{latest_release}#{git_subdir}"
    run "cp #{latest_release_bak}/REVISION #{latest_release}"
  end

  task :reset_subdir do
    set :latest_release, latest_release_bak
  end

  task :create_symlink, except: { no_release: true } do
    on_rollback do
      if previous_release
        run "rm -f #{current_path}; ln -s #{previous_release}#{git_subdir} #{current_path}; true"
      else
        logger.important "no previous release to rollback to, rollback of symlink skipped"
      end
    end

    run "rm -f #{current_path} && ln -s #{latest_release}#{git_subdir} #{current_path}"
  end

  desc "Send email notification of deployment"
  task :notify do
    # diff = `#{source.local.diff(current_revision)}`
    diff_log = %x(#{source.local.log(source.next_revision(current_revision), branch)})
    user = %x(whoami)
    body = %[From: obs-api-deploy@suse.de
To: #{deploy_notification_to.join(", ")}
Subject: obs-api deployed by #{user}

Git log:
#{diff_log}]

    Net::SMTP.start('relay.suse.de', 25) do |smtp|
      smtp.send_message body, 'obs-api-deploy@suse.de', deploy_notification_to
    end
  end

  task :test_suite do
    Dir.glob('**/*.rb').each do |f|
      unless system("ruby -c -d #{f} > /dev/null")
         puts "syntax error in #{f} - will not deploy"
         exit 1
      end
    end
    unless system("rails test")
      puts "Error on rails test - will not deploy"
      exit 1
    end
  end
end
