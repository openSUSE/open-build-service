
if ENV.has_key? 'BS_SVN_USER'
  set :svnuser, ENV['BS_SVN_USER']
else
  set :svnuser, ENV['USER']
end

set :application, "webclient"
set :repository, "svn+ssh://#{svnuser}@forgesvn.novell.com/svn/opensuse/trunk/buildservice/src/#{application}"

# ROLES
#
# change to your servers

role :web, "build.my.domain"
role :app, "build.my.domain"
role :db, "build.my.domain"


set :deploy_to, "/srv/www/opensuse/#{application}"
set :user, "svnuser"

# use common opensuse tasks
load '../common/lib/switchtower/opensuse.rb'
