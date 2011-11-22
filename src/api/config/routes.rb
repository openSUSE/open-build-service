ActionController::Routing::Routes.draw do |map|
  # Add your own custom routes here.
  # The priority is based upon order of creation: first created -> highest priority.

  # Here's a sample route:
  # map.connect 'products/:id', :controller => 'catalog', :action => 'view'
  # Keep in mind you can assign values other than :controller and :action

  # You can have the root of your site routed by hooking up ''
  # -- just remember to delete public/index.html.
  # map.connect '', :controller => "welcome"

  # Allow downloading Web Service WSDL as a file with an extension
  # instead of a file named 'wsdl'
  # map.connect ':controller/service.wsdl', :action => 'wsdl'

  map.connect '/', :controller => 'main'

  map.resource :configuration, :only => [:show, :update]

  ### /person
  map.connect 'person', :controller => 'person', :action => 'index'
  # FIXME: this is no clean namespace, a person "register" or "changepasswd" could exist ...
  #        suggested solution is POST person/:login?cmd=register
  #        fix this for OBS 3.0
  map.connect 'person/register', :controller => 'person', :action => 'register'
  map.connect 'person/changepasswd', :controller => 'person', :action => 'change_my_password'
  # bad api, to be removed for OBS 3. Use /group?person=:login instead
  map.connect 'person/:login/group', :controller => 'person', :action => 'grouplist', :login => /[^\/]*/

  map.connect 'person/:login', :controller => 'person', :action => 'userinfo', :login => /[^\/]*/

  ### /group
  map.connect 'group', :controller => 'group', :action => 'index'
  map.connect 'group/:title', :controller => 'group', :action => 'show', :title => /[^\/]*/

  ### /service
  map.connect 'service/:service', :controller => "service",
    :action => 'index_service', :service => /\w[^\/]*/

  ### /source

  # project level
  map.connect 'source/:project', :controller => "source",
    :action => 'index_project', :project => /\w[^\/]*/
  map.connect 'source/:project/_meta', :controller => 'source',
    :action => 'project_meta', :project => /[^\/]*/
  map.connect 'source/:project/_webui_flags', :controller => 'source',
    :action => 'project_flags', :project => /[^\/]*/
  map.connect 'source/:project/_attribute', :controller => 'source',
    :action => 'attribute_meta', :project => /[^\/]*/
  map.connect 'source/:project/_attribute/:attribute', :controller => 'source',
    :action => 'attribute_meta', :project => /[^\/]*/
  map.connect 'source/:project/_config', :controller => 'source',
    :action => 'project_config', :project => /[^\/]*/
  map.connect 'source/:project/_tags', :controller => 'tag',
    :action => 'project_tags', :project => /[^\/]*/
  map.connect 'source/:project/_pubkey', :controller => 'source',
    :action => 'project_pubkey', :project => /[^\/]*/

  # package level
  map.connect 'source/:project/:package/_meta', :controller => 'source',
    :action => 'package_meta', :project => /[^\/]*/, :package => /[^\/]*/
  map.connect 'source/:project/:package/_webui_flags', :controller => 'source',
    :action => 'package_flags', :project => /[^\/]*/, :package => /[^\/]*/
  map.connect 'source/:project/:package/_attribute', :controller => 'source',
    :action => 'attribute_meta', :project => /[^\/]*/, :package => /[^\/]*/
  map.connect 'source/:project/:package/_attribute/:attribute', :controller => 'source',
    :action => 'attribute_meta', :project => /[^\/]*/, :package => /[^\/]*/
  map.connect 'source/:project/:package/:binary/_attribute', :controller => 'source',
    :action => 'attribute_meta', :project => /[^\/]*/, :package => /[^\/]*/, :binary => /[^\/]*/
  map.connect 'source/:project/:package/:binary/_attribute/:attribute', :controller => 'source',
    :action => 'attribute_meta', :project => /[^\/]*/, :package => /[^\/]*/, :binary => /[^\/]*/
  map.connect 'source/:project/:package/_tags', :controller => 'tag',
    :action => 'package_tags', :project => /[^\/]*/, :package => /[^\/]*/
  map.connect 'source/:project/:package/_wizard', :controller => 'wizard',
    :action => 'package_wizard', :project => /[^\/]*/, :package => /[^\/]*/
  map.connect 'source/:project/:package/:file', :controller => "source",
    :action => 'file', :project => /[^\/]*/, :package => /[^\/]*/, :file => /[^\/]*/
  map.connect 'source/:project/:package', :controller => "source",
    :action => 'index_package', :project => /\w[^\/]*/, :package => /\w[^\/]*/


  ### /attribute
  map.connect 'attribute', :controller => 'attribute',
    :action => 'index'
  map.connect 'attribute/:namespace', :controller => 'attribute',
    :action => 'index'
  map.connect 'attribute/:namespace/_meta', :controller => 'attribute',
    :action => 'namespace_definition'
  map.connect 'attribute/:namespace/:name/_meta', :controller => 'attribute',
    :action => 'attribute_definition'

  ### /architecture
  map.resources :architectures, :only => [:index, :show, :update] # create,delete currently disabled

  ### /issue_trackers
  map.connect 'issue_trackers/issues_in', :controller => 'issue_trackers', :action => 'issues_in'
  map.resources :issue_trackers, :only => [:index, :show, :create, :update, :destroy] do |issue_trackers|
    issue_trackers.resources :issues, :only => [:show] # Nested route
  end

  ### /tag

  #routes for tagging support
  #
  # map.connect 'tag/_all', :controller => 'tag',
  #  :action => 'list_xml'
  #Get/put tags by object
  ### moved to source section

  #Get objects by tag.
  map.connect 'tag/:tag/_projects', :controller => 'tag',
    :action => 'get_projects_by_tag'
  map.connect 'tag/:tag/_packages', :controller => 'tag',
    :action => 'get_packages_by_tag'
  map.connect 'tag/:tag/_all', :controller => 'tag',
    :action => 'get_objects_by_tag'

  #Get a tagcloud including all tags.
  map.connect 'tag/_tagcloud', :controller => 'tag',
    :action => 'tagcloud'


  ### /user

  #Get objects tagged by user. (objects with tags)
  map.connect 'user/:user/tags/_projects', :controller => 'tag',
    :action => 'get_tagged_projects_by_user', :user => /[^\/]*/
  map.connect 'user/:user/tags/_packages', :controller => 'tag',
    :action => 'get_tagged_packages_by_user', :user => /[^\/]*/

  #Get tags by user.
  map.connect 'user/:user/tags/_tagcloud', :controller => 'tag',
    :action =>  'tagcloud', :user => /[^\/]*/
  #map.connect 'user/:user/tags', :controller => 'tag',
  #  :action => 'tagcloud', :distribution => 'raw'

  #Get tags for a certain object by user.
  map.connect 'user/:user/tags/:project', :controller => 'tag',
    :action => 'tags_by_user_and_object', :project => /[^\/]*/, :user => /[^\/]*/
  map.connect 'user/:user/tags/:project/:package', :controller => 'tag',
    :action => 'tags_by_user_and_object', :project => /[^\/]*/, :package => /[^\/]*/, :user => /[^\/]*/


  ### /statistics

  # Routes for statistics
  # ---------------------

  # Download statistics
  #
  map.connect 'statistics/download_counter',
    :controller => 'statistics', :action => 'download_counter'

  # Timestamps
  #
  map.connect 'statistics/added_timestamp/:project',
    :controller => 'statistics', :action => 'added_timestamp', :project => /[^\/]*/
  map.connect 'statistics/added_timestamp/:project/:package',
    :controller => 'statistics', :action => 'added_timestamp', :project => /[^\/]*/, :package => /[^\/]*/
  map.connect 'statistics/updated_timestamp/:project',
    :controller => 'statistics', :action => 'updated_timestamp', :project => /[^\/]*/
  map.connect 'statistics/updated_timestamp/:project/:package',
    :controller => 'statistics', :action => 'updated_timestamp', :project => /[^\/]*/, :package => /[^\/]*/

  # Ratings
  #
  map.connect 'statistics/rating/:project',
    :controller => 'statistics', :action => 'rating', :project => /[^\/]*/
  map.connect 'statistics/rating/:project/:package',
    :controller => 'statistics', :action => 'rating', :project => /[^\/]*/, :package => /[^\/]*/

  # Activity
  #
  map.connect 'statistics/activity/:project',
    :controller => 'statistics', :action => 'activity', :project => /[^\/]*/
  map.connect 'statistics/activity/:project/:package',
    :controller => 'statistics', :action => 'activity', :project => /[^\/]*/, :package => /[^\/]*/

  # Newest stats
  #
  map.connect 'statistics/newest_stats',
    :controller => 'statistics', :action => 'newest_stats'

  ### /status_message

  # Routes for status_messages
  # --------------------------
  map.connect 'status_message',
    :controller => 'status', :action => 'messages'


  ### /message

  # Routes for messages
  # --------------------------
  map.connect 'message/:id',
    :controller => 'message', :action => 'index'


  ### /search

  # ACL(/search/published/binary/id) TODO: direct passed call to  "pass_to_backend"
  map.connect 'search/published/binary/id' , :controller => "search", :action => "pass_to_backend"
  # ACL(/search/published/pattern/id) TODO: direct passed call to  "pass_to_backend"
  map.connect 'search/published/pattern/id' , :controller => "search", :action => "pass_to_backend"
  map.connect 'search/project/id', :controller => "search", :action => "project_id"
  map.connect 'search/package/id', :controller => "search", :action => "package_id"
  map.connect 'search/project', :controller => "search", :action => "project"
  map.connect 'search/package', :controller => "search", :action => "package"
  map.connect 'search/attribute', :controller => "search", :action => "attribute"
  map.connect 'search', :controller => "search", :action => "pass_to_backend"

  ### /build

  map.connect 'build/:project/:repository/:arch/:package/_status',
    :controller => "build", :action => "index", :project => /[^\/]*/, :repository => /[^\/]*/, :package => /[^\/]*/
  map.connect 'build/:project/:repository/:arch/:package/_log',
    :controller => "build", :action => "logfile", :project => /[^\/]*/, :repository => /[^\/]*/, :package => /[^\/]*/
  map.connect 'build/:project/:repository/:arch/:package/_buildinfo',
    :controller => "build", :action => "buildinfo", :project => /[^\/]*/, :repository => /[^\/]*/, :package => /[^\/]*/
  map.connect 'build/:project/:repository/:arch/:package/_history',
    :controller => "build", :action => "index", :project => /[^\/]*/, :repository => /[^\/]*/, :package => /[^\/]*/
  map.connect 'build/:project/:repository/:arch/:package/:filename',
    :controller => "build", :action => "file", :project => /[^\/]*/, :repository => /[^\/]*/, :package => /[^\/]*/, :filename => /[^\/]*/
  map.connect 'build/:project/:repository/:arch/_builddepinfo',
    :controller => "build", :action => "builddepinfo", :project => /[^\/]*/, :repository => /[^\/]*/, :arch => /[^\/]*/
  map.connect 'build/:project/:repository/:arch/:package',
    :controller => "build", :action => "index", :project => /[^\/]*/, :repository => /[^\/]*/, :package => /[^\/]*/
  map.connect 'build/:project/:repository/_buildconfig',
    :controller => "build", :action => "index", :project => /[^\/]*/, :repository => /[^\/]*/
  map.connect 'build/:project/:repository/:arch',
    :controller => "build", :action => "index", :project => /[^\/]*/, :repository => /[^\/]*/
  map.connect 'build/:project/_result',
    :controller => "build", :action => "result", :project => /[^\/]*/
  map.connect 'build/:project/:repository',
    :controller => "build", :action => "index", :project => /[^\/]*/, :repository => /[^\/]*/
  # the web client does no longer use that route, but we keep it for backward compat
  map.connect 'build/_workerstatus',
    :controller => "status", :action => "workerstatus"
  map.connect 'build/:project',
    :controller => "build", :action => "project_index", :project => /[^\/]*/
  map.connect 'build',
    :controller => "source", :action => "index"

  ### /published

  map.connect 'published/:project/:repository/:arch/:binary',
    :controller => "published", :action => "index", :project => /[^\/]*/, :repository => /[^\/]*/, :binary => /[^\/]*/
  map.connect 'published/:project/:repository/:arch', # :arch can be also a ymp for a pattern :/
    :controller => "published", :action => "index", :project => /[^\/]*/, :repository => /[^\/]*/, :arch => /[^\/]*/
  map.connect 'published/:project/:repository/',
    :controller => "published", :action => "index", :project => /[^\/]*/, :repository => /[^\/]*/
  map.connect 'published/:project',
    :controller => "published", :action => "index", :project => /[^\/]*/
  map.connect 'published/',
    :controller => "published", :action => "index"

  ### /request
  
  map.resources :request, :only => [:index, :show, :update]
  
  map.connect 'request/:id', :controller => 'request',
    :action => 'command'
  # ACL(/search/request) TODO: direct passed call to  "pass_to_backend"
  map.connect 'search/request', :controller => 'request', 
    :action => 'pass_to_backend'

  ### /lastevents

  map.connect "/lastevents", :controller => 'public',
    :action => 'lastevents'


  ### /apidocs

  map.connect 'apidocs/:action', :action => /[^\/]*/, :controller => "apidocs"

  map.connect '/active_rbac/registration/confirm/:user/:token',
    :controller => 'active_rbac/registration', :action => 'confirm'


  ### /distributions

  map.connect '/distributions', :controller => "distribution"

  ### /public
    
  map.connect '/public/build/:prj',
    :controller => 'public', :action => 'build', :prj => /[^\/]*/
  map.connect '/public/build/:prj/:repo',
    :controller => 'public', :action => 'build', :prj => /[^\/]*/, :repo => /[^\/]*/
  map.connect '/public/build/:prj/:repo/:arch/:pkg',
    :controller => 'public', :action => 'build', :prj => /[^\/]*/, :repo => /[^\/]*/, :pkg => /[^\/]*/
  map.connect '/public/source/:prj',
    :controller => 'public', :action => 'project_index', :prj => /[^\/]*/
  map.connect '/public/source/:prj/_meta',
    :controller => 'public', :action => 'project_meta', :prj => /[^\/]*/
  map.connect '/public/source/:prj/_config',
    :controller => 'public', :action => 'project_file', :prj => /[^\/]*/
  map.connect '/public/source/:prj/_pubkey',
    :controller => 'public', :action => 'project_file', :prj => /[^\/]*/
  map.connect '/public/source/:prj/:pkg',
    :controller => 'public', :action => 'package_index', :prj => /[^\/]*/, :pkg => /[^\/]*/
  map.connect '/public/source/:prj/:pkg/_meta',
    :controller => 'public', :action => 'package_meta', :prj => /[^\/]*/, :pkg => /[^\/]*/
  map.connect '/public/source/:prj/:pkg/:file',
    :controller => 'public', :action => 'source_file', :prj => /[^\/]*/, :pkg => /[^\/]*/, :file => /[^\/]*/
  map.connect '/public/lastevents',
    :controller => 'public', :action => 'lastevents'
  map.connect '/public/distributions',
    :controller => 'public', :action => 'distributions'
  map.connect '/public/binary_packages/:prj/:pkg',
    :controller => 'public', :action => 'binary_packages', :prj => /[^\/]*/, :pkg => /[^\/]*/
  map.connect 'public/status/:action',
    :controller => 'status'


  ### /status
   
  # action request somehow does not work
  map.connect 'status/request/:id', :controller => 'status', :action => 'request'

  # Install the default route as the lowest priority.
  map.connect ':controller/:action/:id', :id => /[^\/]*/
  map.connect ':controller/:action'
end
