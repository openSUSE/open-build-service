OBSApi::Application.routes.draw do

  match '/' => 'main'

  resources :configuration, :only => [:show, :update]

  ### /person
  match 'person' => 'person#index'
  # FIXME: this is no clean namespace, a person "register" or "changepasswd" could exist ...
  #        suggested solution is POST person/:login?cmd=register
  #        fix this for OBS 3.0
  match 'person/register' => 'person#register'
  match 'person/changepasswd' => 'person#change_my_password'
  # bad api, to be removed for OBS 3. Use /group?person=:login instead
  match 'person/:login/group' => 'person#grouplist', :login => /[^\/]*/

  match 'person/:login' => 'person#userinfo', :login => /[^\/]*/

  ### /group
  match 'group' => 'group#index'
  match 'group/:title' => 'group#show', :title => /[^\/]*/

  ### /service
  match 'service/:service' => "service",
    :action => 'index_service', :service => /\w[^\/]*/

  ### /source

  # project level
  match 'source/:project' => "source",
    :action => 'index_project', :project => /\w[^\/]*/
  match 'source/:project/_meta' => 'source',
    :action => 'project_meta', :project => /[^\/]*/
  match 'source/:project/_webui_flags' => 'source',
    :action => 'project_flags', :project => /[^\/]*/
  match 'source/:project/_attribute' => 'source',
    :action => 'attribute_meta', :project => /[^\/]*/
  match 'source/:project/_attribute/:attribute' => 'source',
    :action => 'attribute_meta', :project => /[^\/]*/
  match 'source/:project/_config' => 'source',
    :action => 'project_config', :project => /[^\/]*/
  match 'source/:project/_tags' => 'tag',
    :action => 'project_tags', :project => /[^\/]*/
  match 'source/:project/_pubkey' => 'source',
    :action => 'project_pubkey', :project => /[^\/]*/

  # package level
  match 'source/:project/:package/_meta' => 'source',
    :action => 'package_meta', :project => /[^\/]*/, :package => /[^\/]*/
  match 'source/:project/:package/_webui_flags' => 'source',
    :action => 'package_flags', :project => /[^\/]*/, :package => /[^\/]*/
  match 'source/:project/:package/_attribute' => 'source',
    :action => 'attribute_meta', :project => /[^\/]*/, :package => /[^\/]*/
  match 'source/:project/:package/_attribute/:attribute' => 'source',
    :action => 'attribute_meta', :project => /[^\/]*/, :package => /[^\/]*/
  match 'source/:project/:package/:binary/_attribute' => 'source',
    :action => 'attribute_meta', :project => /[^\/]*/, :package => /[^\/]*/, :binary => /[^\/]*/
  match 'source/:project/:package/:binary/_attribute/:attribute' => 'source',
    :action => 'attribute_meta', :project => /[^\/]*/, :package => /[^\/]*/, :binary => /[^\/]*/
  match 'source/:project/:package/_tags' => 'tag',
    :action => 'package_tags', :project => /[^\/]*/, :package => /[^\/]*/
  match 'source/:project/:package/_wizard' => 'wizard',
    :action => 'package_wizard', :project => /[^\/]*/, :package => /[^\/]*/
  match 'source/:project/:package/:file' => "source",
    :action => 'file', :project => /[^\/]*/, :package => /[^\/]*/, :file => /[^\/]*/
  match 'source/:project/:package' => "source",
    :action => 'index_package', :project => /\w[^\/]*/, :package => /\w[^\/]*/


  ### /attribute
  match 'attribute' => 'attribute',
    :action => 'index'
  match 'attribute/:namespace' => 'attribute',
    :action => 'index'
  match 'attribute/:namespace/_meta' => 'attribute',
    :action => 'namespace_definition'
  match 'attribute/:namespace/:name/_meta' => 'attribute',
    :action => 'attribute_definition'

  ### /architecture
  resourcess :architectures, :only => [:index, :show, :update] # create,delete currently disabled

  ### /issue_trackers
  match 'issue_trackers/issues_in' => 'issue_trackers#issues_in'
  resourcess :issue_trackers, :only => [:index, :show, :create, :update, :destroy] do |issue_trackers|
    issue_trackers.resources :issues, :only => [:show] # Nested route
  end

  ### /tag

  #routes for tagging support
  #
  # match 'tag/_all' => 'tag',
  #  :action => 'list_xml'
  #Get/put tags by object
  ### moved to source section

  #Get objects by tag.
  match 'tag/:tag/_projects' => 'tag',
    :action => 'get_projects_by_tag'
  match 'tag/:tag/_packages' => 'tag',
    :action => 'get_packages_by_tag'
  match 'tag/:tag/_all' => 'tag',
    :action => 'get_objects_by_tag'

  #Get a tagcloud including all tags.
  match 'tag/_tagcloud' => 'tag',
    :action => 'tagcloud'


  ### /user

  #Get objects tagged by user. (objects with tags)
  match 'user/:user/tags/_projects' => 'tag',
    :action => 'get_tagged_projects_by_user', :user => /[^\/]*/
  match 'user/:user/tags/_packages' => 'tag',
    :action => 'get_tagged_packages_by_user', :user => /[^\/]*/

  #Get tags by user.
  match 'user/:user/tags/_tagcloud' => 'tag',
    :action => 'tagcloud', :user => /[^\/]*/
  #match 'user/:user/tags' => 'tag',
  #  :action => 'tagcloud', :distribution => 'raw'

  #Get tags for a certain object by user.
  match 'user/:user/tags/:project' => 'tag',
    :action => 'tags_by_user_and_object', :project => /[^\/]*/, :user => /[^\/]*/
  match 'user/:user/tags/:project/:package' => 'tag',
    :action => 'tags_by_user_and_object', :project => /[^\/]*/, :package => /[^\/]*/, :user => /[^\/]*/


  ### /statistics

  # Routes for statistics
  # ---------------------

  # Download statistics
  #
  match 'statistics/download_counter',
    :controller => 'statistics#download_counter'

  # Timestamps
  #
  match 'statistics/added_timestamp/:project',
    :controller => 'statistics#added_timestamp', :project => /[^\/]*/
  match 'statistics/added_timestamp/:project/:package',
    :controller => 'statistics#added_timestamp', :project => /[^\/]*/, :package => /[^\/]*/
  match 'statistics/updated_timestamp/:project',
    :controller => 'statistics#updated_timestamp', :project => /[^\/]*/
  match 'statistics/updated_timestamp/:project/:package',
    :controller => 'statistics#updated_timestamp', :project => /[^\/]*/, :package => /[^\/]*/

  # Ratings
  #
  match 'statistics/rating/:project',
    :controller => 'statistics#rating', :project => /[^\/]*/
  match 'statistics/rating/:project/:package',
    :controller => 'statistics#rating', :project => /[^\/]*/, :package => /[^\/]*/

  # Activity
  #
  match 'statistics/activity/:project',
    :controller => 'statistics#activity', :project => /[^\/]*/
  match 'statistics/activity/:project/:package',
    :controller => 'statistics#activity', :project => /[^\/]*/, :package => /[^\/]*/

  # Newest stats
  #
  match 'statistics/newest_stats',
    :controller => 'statistics#newest_stats'

  ### /status_message

  # Routes for status_messages
  # --------------------------
  match 'status_message',
    :controller => 'status#messages'


  ### /message

  # Routes for messages
  # --------------------------
  match 'message/:id',
    :controller => 'message#index'


  ### /search

  # ACL(/search/published/binary/id) TODO: direct passed call to  "pass_to_backend"
  match 'search/published/binary/id'  => "search", :action => "pass_to_backend"
  # ACL(/search/published/pattern/id) TODO: direct passed call to  "pass_to_backend"
  match 'search/published/pattern/id'  => "search", :action => "pass_to_backend"
  match 'search/project/id' => "search", :action => "project_id"
  match 'search/package/id' => "search", :action => "package_id"
  match 'search/project' => "search", :action => "project"
  match 'search/package' => "search", :action => "package"
  match 'search/attribute' => "search", :action => "attribute"
  match 'search' => "search", :action => "pass_to_backend"

  ### /build

  match 'build/:project/:repository/:arch/:package/_status',
    :controller => "build", :action => "index", :project => /[^\/]*/, :repository => /[^\/]*/, :package => /[^\/]*/
  match 'build/:project/:repository/:arch/:package/_log',
    :controller => "build", :action => "logfile", :project => /[^\/]*/, :repository => /[^\/]*/, :package => /[^\/]*/
  match 'build/:project/:repository/:arch/:package/_buildinfo',
    :controller => "build", :action => "buildinfo", :project => /[^\/]*/, :repository => /[^\/]*/, :package => /[^\/]*/
  match 'build/:project/:repository/:arch/:package/_history',
    :controller => "build", :action => "index", :project => /[^\/]*/, :repository => /[^\/]*/, :package => /[^\/]*/
  match 'build/:project/:repository/:arch/:package/:filename',
    :controller => "build", :action => "file", :project => /[^\/]*/, :repository => /[^\/]*/, :package => /[^\/]*/, :filename => /[^\/]*/
  match 'build/:project/:repository/:arch/_builddepinfo',
    :controller => "build", :action => "builddepinfo", :project => /[^\/]*/, :repository => /[^\/]*/, :arch => /[^\/]*/
  match 'build/:project/:repository/:arch/:package',
    :controller => "build", :action => "index", :project => /[^\/]*/, :repository => /[^\/]*/, :package => /[^\/]*/
  match 'build/:project/:repository/_buildconfig',
    :controller => "build", :action => "index", :project => /[^\/]*/, :repository => /[^\/]*/
  match 'build/:project/:repository/:arch',
    :controller => "build", :action => "index", :project => /[^\/]*/, :repository => /[^\/]*/
  match 'build/:project/_result',
    :controller => "build", :action => "result", :project => /[^\/]*/
  match 'build/:project/:repository',
    :controller => "build", :action => "index", :project => /[^\/]*/, :repository => /[^\/]*/
  # the web client does no longer use that route, but we keep it for backward compat
  match 'build/_workerstatus',
    :controller => "status", :action => "workerstatus"
  match 'build/:project',
    :controller => "build", :action => "project_index", :project => /[^\/]*/
  match 'build',
    :controller => "source", :action => "index"

  ### /published

  match 'published/:project/:repository/:arch/:binary',
    :controller => "published", :action => "index", :project => /[^\/]*/, :repository => /[^\/]*/, :binary => /[^\/]*/
  match 'published/:project/:repository/:arch', # :arch can be also a ymp for a pattern :/
    :controller => "published", :action => "index", :project => /[^\/]*/, :repository => /[^\/]*/, :arch => /[^\/]*/
  match 'published/:project/:repository/',
    :controller => "published", :action => "index", :project => /[^\/]*/, :repository => /[^\/]*/
  match 'published/:project',
    :controller => "published", :action => "index", :project => /[^\/]*/
  match 'published/',
    :controller => "published", :action => "index"

  ### /request
  
  resourcess :request, :only => [:index, :show, :update, :create]
  
  match 'request/:id' => 'request',
    :action => 'command'
  # ACL(/search/request) TODO: direct passed call to  "pass_to_backend"
  match 'search/request' => 'request', 
    :action => 'pass_to_backend'

  ### /lastevents

  match "/lastevents" => 'public',
    :action => 'lastevents'


  ### /apidocs

  match 'apidocs/:action', :action => /[^\/]*/ => "apidocs"

  match '/active_rbac/registration/confirm/:user/:token',
    :controller => 'active_rbac/registration#confirm'


  ### /distributions

  match '/distributions' => "distribution"

  ### /public
    
  match '/public/build/:prj',
    :controller => 'public#build', :prj => /[^\/]*/
  match '/public/build/:prj/:repo',
    :controller => 'public#build', :prj => /[^\/]*/, :repo => /[^\/]*/
  match '/public/build/:prj/:repo/:arch/:pkg',
    :controller => 'public#build', :prj => /[^\/]*/, :repo => /[^\/]*/, :pkg => /[^\/]*/
  match '/public/source/:prj',
    :controller => 'public#project_index', :prj => /[^\/]*/
  match '/public/source/:prj/_meta',
    :controller => 'public#project_meta', :prj => /[^\/]*/
  match '/public/source/:prj/_config',
    :controller => 'public#project_file', :prj => /[^\/]*/
  match '/public/source/:prj/_pubkey',
    :controller => 'public#project_file', :prj => /[^\/]*/
  match '/public/source/:prj/:pkg',
    :controller => 'public#package_index', :prj => /[^\/]*/, :pkg => /[^\/]*/
  match '/public/source/:prj/:pkg/_meta',
    :controller => 'public#package_meta', :prj => /[^\/]*/, :pkg => /[^\/]*/
  match '/public/source/:prj/:pkg/:file',
    :controller => 'public#source_file', :prj => /[^\/]*/, :pkg => /[^\/]*/, :file => /[^\/]*/
  match '/public/lastevents',
    :controller => 'public#lastevents'
  match '/public/distributions',
    :controller => 'public#distributions'
  match '/public/binary_packages/:prj/:pkg',
    :controller => 'public#binary_packages', :prj => /[^\/]*/, :pkg => /[^\/]*/
  match 'public/status/:action',
    :controller => 'status'


  ### /status
   
  # action request somehow does not work
  match 'status/request/:id' => 'status#request'

  # Install the default route as the lowest priority.
  match ':controller/:action/:id', :id => /[^\/]*/
  match ':controller/:action'
end
