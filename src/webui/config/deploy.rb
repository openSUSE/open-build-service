require 'net/smtp'

depend :local, :gem, 'capistrano', '>=2.11.2'

set :application, "obs-webui"

# git settings
set :scm, :git
set :repository,  "git://github.com/openSUSE/open-build-service.git"
set :branch, "2.3"
set :deploy_via, :remote_cache
set :git_enable_submodules, 1
set :git_subdir, '/src/webui'
set :migrate_target, :current

set :deploy_notification_to, ['tschmidt@suse.de', 'coolo@suse.de', 'adrian@suse.de', 'mls@suse.de']
server "buildserviceapi.suse.de", :app, :web, :db, :primary => true


# If you aren't deploying to /u/apps/#{application} on the target
# servers (which is the default), you can specify the actual location
# via the :deploy_to variable:
set :deploy_to, "/srv/www/vhosts/opensuse.org/#{application}"
set :runit_name, "webclient"
set :static, "build2.o.o"
set :owner, "webuirun"
set :rails_env, "production"

# set variables for different target deployments
task :stage do
  set :deploy_to, "/srv/www/vhosts/opensuse.org/stage/#{application}"
  set :runit_name, "webclient_stage"
  set :branch, "2.3"
  set :static, "build.o.o-stage/stage"
  set :owner, "swebuirun"
  set :rails_env, "stage"
end

ssh_options[:forward_agent] = true
default_run_options[:pty] = true
set :normalize_asset_timestamps, false

# tasks are run with this user
set :user, "root"
# spinner is run with this user
set :runner, "root"

after "deploy:update_code", "config:symlink_shared_config"
after "deploy:update_code", "config:sync_static"
after "deploy:create_symlink", "config:permissions"

# workaround because we are using a subdirectory of the git repo as rails root
before "deploy:finalize_update", "deploy:use_subdir"
after "deploy:finalize_update", "deploy:reset_subdir"
after "deploy:finalize_update", "deploy:notify"

after :deploy, 'deploy:cleanup' # only keep 5 releases
before "deploy:update_code", "deploy:test_suite"

namespace :config do

  desc "Install saved configs from /shared/ dir"
  task :symlink_shared_config do
    run "ln -s #{shared_path}/options.yml #{release_path}#{git_subdir}/config/"
    run "ln -s #{shared_path}/secret.key #{release_path}#{git_subdir}/config/"
    run "rm -f #{release_path}#{git_subdir}/config/environments/#{rails_env}.rb"
    run "ln -s #{shared_path}/#{rails_env}.rb #{release_path}#{git_subdir}/config/environments/"
    run "ln -s #{shared_path}/repositories.rb #{release_path}#{git_subdir}/config/"
    #not in git anymore
    #run "rm -fr #{release_path}#{git_subdir}/app/views/maintenance"
    run "ln -s #{shared_path}/maintenance #{release_path}#{git_subdir}/app/views"
    run "ln -s #{shared_path}/database.yml #{release_path}#{git_subdir}/config/database.yml"
  end

  desc "Patch local changes"
  task :patch_build_opensuse_org do
    run "cd #{current_path}; patch -p3 < config/build.opensuse.org.diff"
  end

  desc "Set permissions"
  task :permissions do
    run "mkdir -p #{release_path}#{git_subdir}/public/main"
    run "chown -R #{owner} #{current_path}/tmp #{release_path}#{git_subdir}/public/main"
  end

  desc "Sync public to static.o.o"
  task :sync_static do
    `rsync --delete-after --exclude=themes -rltDOv --chmod ug=rwX,o=rX public/ -e 'ssh -p2212' proxy-opensuse.suse.de:/srv/www/vhosts/static.opensuse.org/hosts/#{static}`
    # Secondary (high-availability) VM for static needs the same content
    `rsync --delete-after --exclude=themes -rltDOv --chmod ug=rwX,o=rX public/ -e 'ssh -p2213' proxy-opensuse.suse.de:/srv/www/vhosts/static.opensuse.org/hosts/#{static}`
  end

end

# server restarting
namespace :deploy do
  task :restart do
    run "touch #{current_path}/tmp/restart.txt"
  end

  task :use_subdir do
    set :latest_release_bak, latest_release
    set :latest_release, "#{latest_release}#{git_subdir}"
    run "cp #{latest_release_bak}/REVISION #{latest_release}"
  end

  task :reset_subdir do
    set :latest_release, latest_release_bak
  end

  task :create_symlink, :except => { :no_release => true } do
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
    #diff = `#{source.local.diff(current_revision)}`
    diff_log = `#{source.local.log(source.local.next_revision(current_revision), branch)}`
    user = `whoami`
    body = %Q[From: obs-webui-deploy@suse.de
To: #{deploy_notification_to.join(", ")}
Subject: obs-#{runit_name} deployed by #{user}

Git log:
#{diff_log}]

    Net::SMTP.start('relay.suse.de', 25) do |smtp|
      smtp.send_message body, 'obs-webui-deploy@suse.de', deploy_notification_to
    end
  end
  
  task :test_suite do
    Dir.glob('**/*.rb').each do |f|
      if !system("ruby -c -d #{f} > /dev/null")
         puts "syntax error in #{f} - will not deploy"
         exit 1
      end
    end
    if !system("rake --trace check_syntax")
      puts "Error in syntax check - will not deploy"
      exit 1
    end
    if !system("rake test")
      puts "Error on rake test - will not deploy"
      exit 1
    end
  end

end


