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

  ### /person

  map.connect 'person/register', :controller => 'person', :action => 'register'
  map.connect 'person/:login', :controller => 'person', :action => 'userinfo', :login => /[^\/]*/

  ### /result

  map.connect 'result/:project/result', :controller => 'result',
    :action => 'projectresult', :project => /[^\/]*/
  map.connect 'result/:project/packstatus', :controller => 'result',
    :action => 'packstatus', :project => /[^\/]*/
  map.connect 'result/:project/:platform/result', :controller => 'result',
    :action => 'projectresult', :project => /[^\/]*/, :platform => /[^\/]*/
  map.connect 'result/:project/:platform/:package/result', :controller => 'result',
    :action => 'packageresult', :project => /[^\/]*/, :platform => /[^\/]*/, :package => /[^\/]*/
  map.connect 'result/:project/:platform/:package/:arch/log',
    :controller => 'result',
    :action => 'log', :project => /[^\/]*/, :platform => /[^\/]*/, :package => /[^\/]*/

  ### /repository

  map.connect 'repository', :controller => 'repository', :action => 'index'

  ### /source

  # project level
  map.connect 'source/:project', :controller => "source",
    :action => 'index_project', :project => /\w[^\/]*/
  map.connect 'source/:project/_pattern/:pattern', :controller => 'source',
    :action => 'pattern_meta', :project => /[^\/]*/, :pattern => /[^\/]*/
  map.connect 'source/:project/_meta', :controller => 'source',
    :action => 'project_meta', :project => /[^\/]*/
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
  map.connect 'source/:project/_pattern', :controller => 'source',
    :action => 'index_pattern', :project => /[^\/]*/
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

  map.connect 'search/published/binary/id' , :controller => "search", :action => "pass_to_backend"
  map.connect 'search/published/pattern/id' , :controller => "search", :action => "pass_to_backend"
  map.connect 'search/project/id', :controller => "search", :action => "project_id"
  map.connect 'search/package/id', :controller => "search", :action => "package_id"
  map.connect 'search/project', :controller => "search", :action => "project"
  map.connect 'search/package', :controller => "search", :action => "package"
  map.connect 'search/attribute', :controller => "search", :action => "attribute"
  map.connect 'search', :controller => "search", :action => "pass_to_backend"

  ### /build

  map.connect 'build/:project/:repository/:arch/:package/_status',
    :controller => "build", :action => "pass_to_backend", :project => /[^\/]*/, :repository => /[^\/]*/, :package => /[^\/]*/
  map.connect 'build/:project/:repository/:arch/:package/_log',
    :controller => "build", :action => "pass_to_backend", :project => /[^\/]*/, :repository => /[^\/]*/, :package => /[^\/]*/
  map.connect 'build/:project/:repository/:arch/:package/_buildinfo',
    :controller => "build", :action => "buildinfo", :project => /[^\/]*/, :repository => /[^\/]*/, :package => /[^\/]*/
  map.connect 'build/:project/:repository/:arch/:package/_history',
    :controller => "build", :action => "pass_to_backend", :project => /[^\/]*/, :repository => /[^\/]*/, :package => /[^\/]*/
  map.connect 'build/:project/:repository/:arch/:package/:filename',
    :controller => "build", :action => "file", :project => /[^\/]*/, :repository => /[^\/]*/, :package => /[^\/]*/, :filename => /[^\/]*/
  map.connect 'build/:project/:repository/:arch/_builddepinfo',
    :controller => "build", :action => "pass_to_backend", :project => /[^\/]*/, :repository => /[^\/]*/, :package => /[^\/]*/
  map.connect 'build/:project/:repository/:arch/:package',
    :controller => "build", :action => "package_index", :project => /[^\/]*/, :repository => /[^\/]*/, :package => /[^\/]*/
  map.connect 'build/:project/:repository/_buildconfig',
    :controller => "build", :action => "pass_to_backend", :project => /[^\/]*/, :repository => /[^\/]*/
  map.connect 'build/:project/:repository/:arch',
    :controller => "build", :action => "pass_to_backend", :project => /[^\/]*/, :repository => /[^\/]*/
  map.connect 'build/:project/_result',
    :controller => "build", :action => "pass_to_backend", :project => /[^\/]*/
  map.connect 'build/:project/:repository',
    :controller => "build", :action => "pass_to_backend", :project => /[^\/]*/, :repository => /[^\/]*/
  # the web client does no longer use that route, but we keep it for backward compat
  map.connect 'build/_workerstatus',
    :controller => "status", :action => "workerstatus"
  map.connect 'build/:project',
    :controller => "build", :action => "project_index", :project => /[^\/]*/
  map.connect 'build',
    :controller => "build", :action => "pass_to_backend"

  ### /published

  map.connect 'published/:project/:repository/:arch/:binary',
    :controller => "published", :action => "binary", :project => /[^\/]*/, :repository => /[^\/]*/, :binary => /[^\/]*/
  map.connect 'published/:project/:repository/:arch', # :arch can be also a ymp for a pattern :/
    :controller => "published", :action => "pass_to_backend", :project => /[^\/]*/, :repository => /[^\/]*/, :arch => /[^\/]*/
  map.connect 'published/:project/:repository/',
    :controller => "published", :action => "pass_to_backend", :project => /[^\/]*/, :repository => /[^\/]*/
  map.connect 'published/:project',
    :controller => "published", :action => "pass_to_backend", :project => /[^\/]*/
  map.connect 'published/',
    :controller => "published", :action => "pass_to_backend"

  ### /request
  
  map.resources :request
  
  map.connect 'request/:id', :controller => 'request',
    :action => 'modify'
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
    
  map.connect '/public/build/:prj/:repo/:arch/:pkg',
    :controller => 'public', :action => 'build', :prj => /[^\/]*/, :repo => /[^\/]*/, :pkg => /[^\/]*/
  map.connect '/public/source/:prj',
    :controller => 'public', :action => 'project_index', :prj => /[^\/]*/
  map.connect '/public/source/:prj/_meta',
    :controller => 'public', :action => 'project_meta', :prj => /[^\/]*/
  map.connect '/public/source/:prj/_config',
    :controller => 'public', :action => 'project_config', :prj => /[^\/]*/
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
  map.connect '/public/binary_packages/:project/:package',
    :controller => 'public', :action => 'binary_packages', :project => /[^\/]*/, :package => /[^\/]*/
  map.connect 'public/status/:action',
    :controller => 'status'


  # Install the default route as the lowest priority.
  map.connect ':controller/:action/:id', :id => /[^\/]*/
  map.connect ':controller/:action'
end
