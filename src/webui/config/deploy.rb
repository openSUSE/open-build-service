set :application, "obs-webui"

# git settings
set :scm, :git
set :repository,  "git://gitorious.org/opensuse/build-service.git"
set :branch, "master"
set :deploy_via, :remote_cache
set :git_enable_submodules, 1
set :git_subdir, '/src/webui'

# If you aren't deploying to /u/apps/#{application} on the target
# servers (which is the default), you can specify the actual location
# via the :deploy_to variable:
set :deploy_to, "/srv/www/vhosts/opensuse.org/#{application}"


ssh_options[:forward_agent] = true
default_run_options[:pty] = true
set :normalize_asset_timestamps, false


# tasks are run with this user
set :user, "root"
# spinner is run with this user
set :runner, "root"
server "buildserviceapi.suse.de", :app, :web, :db, :primary => true


after "deploy:update_code", "config:symlink_shared_config"
after "deploy:symlink", "config:permissions"

# workaround because we are using a subdirectory of the git repo as rails root
before "deploy:finalize_update", "deploy:use_subdir"
after "deploy:finalize_update", "deploy:reset_subdir"

after :deploy, 'deploy:cleanup' # only keep 5 releases


namespace :config do

  desc "Install saved configs from /shared/ dir"
  task :symlink_shared_config do
    run "rm #{release_path}#{git_subdir}/config/options.yml"
    run "ln -s #{shared_path}/options.yml #{release_path}#{git_subdir}/config/"
    run "rm #{release_path}#{git_subdir}/config/environments/production.rb"
    run "ln -s #{shared_path}/production.rb #{release_path}#{git_subdir}/config/environments/"
    run "ln -s #{shared_path}/database.db #{release_path}#{git_subdir}/db/"
    run "ln -s #{shared_path}/repositories.rb #{release_path}#{git_subdir}/config/"
    run "rm -r #{release_path}#{git_subdir}/app/views/maintenance"
    run "ln -s #{shared_path}/maintenance #{release_path}#{git_subdir}/app/views"
  end

  desc "Set permissions"
  task :permissions do
    #run "chown -R wwwrun #{current_path}/public"
  end
end

# server restarting
namespace :deploy do
  task :start do
    run "sv start /service/webclient-*"
  end

  task :restart do
    run "sv 1 /service/webclient-*"
  end

  task :stop do
    run "sv stop /service/webclient-*"
  end

  task :use_subdir do
    set :latest_release_bak, latest_release
    set :latest_release, "#{latest_release}#{git_subdir}"
  end

  task :reset_subdir do
    set :latest_release, latest_release_bak
  end

end




