
# =============================================================================
# REQUIRED VARIABLES
# =============================================================================
# You must always specify the application and repository for every recipe. The
# repository must be the URL of the repository you want this recipe to
# correspond to. The deploy_to path must be the path on each machine that will
# form the root of the application path.

set :svnuser, ENV['USER']
set :application, "backend-dummy"
set :repository, "--username #{svnuser} https://svn.suse.de/svn/opensuse/trunk/buildservice/src/#{application}"

set :server_port, 3002

# =============================================================================
# ROLES
# =============================================================================
# You can define any number of roles, each of which contains any number of
# machines. Roles might include such things as :web, or :app, or :db, defining
# what the purpose of each machine is. You can also specify options that can
# be used to single out a specific subset of boxes in a particular role, like
# :primary => true.

role :web, "buildserviceapi.suse.de"
role :app, "buildserviceapi.suse.de"
role :db,  "buildserviceapi.suse.de"
#role :web, "www01.example.com", "www02.example.com"
#role :app, "app01.example.com", "app02.example.com", "app03.example.com"
#role :db,  "db01.example.com", :primary => true
#role :db,  "db02.example.com", "db03.example.com"

# =============================================================================
# OPTIONAL VARIABLES
# =============================================================================
# set :deploy_to, "/path/to/app" # defaults to "/u/apps/#{application}"
set :deploy_to, "/srv/www/opensuse/#{application}"
set :user, "opensuse"
# set :user, "flippy"            # defaults to the currently logged in user
# set :scm, :darcs               # defaults to :subversion
# set :svn, "/path/to/svn"       # defaults to searching the PATH
# set :darcs, "/path/to/darcs"   # defaults to searching the PATH
# set :cvs, "/path/to/cvs"       # defaults to searching the PATH
# set :gateway, "gate.host.com"  # default to no gateway

# =============================================================================
# SSH OPTIONS
# =============================================================================
# ssh_options[:keys] = %w(/path/to/my/key /path/to/another/key)
# ssh_options[:port] = 25

# =============================================================================
# TASKS
# =============================================================================
# Define tasks that run on all (or only some) of the machines. You can specify
# a role (or set of roles) that each task should be executed on. You can also
# narrow the set of servers to a subset of a role by specifying options, which
# must match the options given for the servers to select (like :primary => true)

# use common opensuse tasks
load '../common/lib/switchtower/opensuse.rb'

task :after_update_code, :roles => :web do
  run <<-CMD
    rm -rf #{current_release}/data &&
    echo "copying data from #{previous_release} to #{release_path}" &&
    cp -rf #{previous_release}/data #{release_path}
  CMD
end
