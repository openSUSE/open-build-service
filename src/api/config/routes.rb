OBSApi::Application.routes.draw do

  match '/' => 'main#index'

  resource :configuration, :only => [:show, :update]

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
  match 'service/:service' => 'service#index_service', :service => /\w[^\/]*/

  ### /source

  # project level
  match 'source/:project' => 'source#index_project', :project => /\w[^\/]*/
  match 'source/:project/_meta' => 'source#project_meta', :project => /[^\/]*/
  match 'source/:project/_webui_flags' => 'source#project_flags', :project => /[^\/]*/
  match 'source/:project/_attribute' => 'source#attribute_meta', :project => /[^\/]*/
  match 'source/:project/_attribute/:attribute' => 'source#attribute_meta', :project => /[^\/]*/
  match 'source/:project/_config' => 'source#project_config', :project => /[^\/]*/
  match 'source/:project/_tags' => 'tag#project_tags', :project => /[^\/]*/
  match 'source/:project/_pubkey' => 'source#project_pubkey', :project => /[^\/]*/

  # package level
  match 'source/:project/:package/_meta' => 'source#package_meta', :project => /[^\/]*/, :package => /[^\/]*/
  match 'source/:project/:package/_webui_flags' => 'source#package_flags', :project => /[^\/]*/, :package => /[^\/]*/
  match 'source/:project/:package/_attribute' => 'source#attribute_meta', :project => /[^\/]*/, :package => /[^\/]*/
  match 'source/:project/:package/_attribute/:attribute' => 'source#attribute_meta', :project => /[^\/]*/, :package => /[^\/]*/
  match 'source/:project/:package/:binary/_attribute' => 'source#attribute_meta', :project => /[^\/]*/, :package => /[^\/]*/, :binary => /[^\/]*/
  match 'source/:project/:package/:binary/_attribute/:attribute' => 'source#attribute_meta', :project => /[^\/]*/, :package => /[^\/]*/, :binary => /[^\/]*/
  match 'source/:project/:package/_tags' => 'tag#package_tags', :project => /[^\/]*/, :package => /[^\/]*/
  match 'source/:project/:package/_wizard' => 'wizard#package_wizard', :project => /[^\/]*/, :package => /[^\/]*/
  match 'source/:project/:package/:file' => 'source#file', :project => /[^\/]*/, :package => /[^\/]*/, :file => /[^\/]*/
  match 'source/:project/:package' => 'source#index_package', :project => /\w[^\/]*/, :package => /\w[^\/]*/


  ### /attribute
  match 'attribute' => 'attribute#index'
  match 'attribute/:namespace' => 'attribute#index'
  match 'attribute/:namespace/_meta' => 'attribute#namespace_definition'
  match 'attribute/:namespace/:name/_meta' => 'attribute#attribute_definition'

  ### /architecture
  resources :architectures, :only => [:index, :show, :update] # create,delete currently disabled

  ### /issue_trackers
  match 'issue_trackers/issues_in' => 'issue_trackers#issues_in'
  resources :issue_trackers, :only => [:index, :show, :create, :update, :destroy] do
    resources :issues, :only => [:show] # Nested route
  end

  ### /tag

  #routes for tagging support
  #
  # match 'tag/_all' => 'tag',
  #  :action => 'list_xml'
  #Get/put tags by object
  ### moved to source section

  #Get objects by tag.
  match 'tag/:tag/_projects' => 'tag#get_projects_by_tag'
  match 'tag/:tag/_packages' => 'tag#get_packages_by_tag'
  match 'tag/:tag/_all' => 'tag#get_objects_by_tag'

  #Get a tagcloud including all tags.
  match 'tag/_tagcloud' => 'tag#tagcloud'


  ### /user

  #Get objects tagged by user. (objects with tags)
  match 'user/:user/tags/_projects' => 'tag#get_tagged_projects_by_user', :user => /[^\/]*/
  match 'user/:user/tags/_packages' => 'tag#get_tagged_packages_by_user', :user => /[^\/]*/

  #Get tags by user.
  match 'user/:user/tags/_tagcloud' => 'tag#tagcloud', :user => /[^\/]*/

  #Get tags for a certain object by user.
  match 'user/:user/tags/:project' => 'tag#tags_by_user_and_object', :project => /[^\/]*/, :user => /[^\/]*/
  match 'user/:user/tags/:project/:package' => 'tag#tags_by_user_and_object', :project => /[^\/]*/, :package => /[^\/]*/, :user => /[^\/]*/


  ### /statistics

  # Routes for statistics
  # ---------------------

  # Download statistics
  #
  match 'statistics/download_counter' => 'statistics#download_counter'

  # Timestamps
  #
  match 'statistics/added_timestamp/:project' => 'statistics#added_timestamp', :project => /[^\/]*/
  match 'statistics/added_timestamp/:project/:package' => 'statistics#added_timestamp', 
     :project => /[^\/]*/, :package => /[^\/]*/
  match 'statistics/updated_timestamp/:project' => 'statistics#updated_timestamp', :project => /[^\/]*/
  match 'statistics/updated_timestamp/:project/:package' => 'statistics#updated_timestamp',
      :project => /[^\/]*/, :package => /[^\/]*/

  # Ratings
  #
  match 'statistics/rating/:project' => 'statistics#rating', :project => /[^\/]*/
  match 'statistics/rating/:project/:package' => 'statistics#rating', :project => /[^\/]*/, :package => /[^\/]*/

  # Activity
  #
  match 'statistics/activity/:project' => 'statistics#activity', :project => /[^\/]*/
  match 'statistics/activity/:project/:package' => 'statistics#activity', :project => /[^\/]*/, :package => /[^\/]*/

  # Newest stats
  #
  match 'statistics/newest_stats' => 'statistics#newest_stats'

  ### /status_message

  # Routes for status_messages
  # --------------------------
  match 'status_message' => 'status#messages'

  ### /message

  # Routes for messages
  # --------------------------
  match 'message/:id' => 'message#index'


  ### /search

  # ACL(/search/published/binary/id) TODO: direct passed call to  "pass_to_backend'
  match 'search/published/binary/id' => 'search#pass_to_backend'
  # ACL(/search/published/pattern/id) TODO: direct passed call to  'pass_to_backend'
  match 'search/published/pattern/id'  => 'search#pass_to_backend'
  match 'search/project/id' => 'search#project_id'
  match 'search/package/id' => 'search#package_id'
  match 'search/project' => 'search#project'
  match 'search/package' => 'search#package'
  match 'search/attribute' => 'search#attribute'
  match 'search' => 'search#pass_to_backend'

  ### /build

  match 'build/:project/:repository/:arch/:package/_status' => 'build#index',
    :project => /[^\/]*/, :repository => /[^\/]*/, :package => /[^\/]*/
  match 'build/:project/:repository/:arch/:package/_log' => 'build#logfile', 
    :project => /[^\/]*/, :repository => /[^\/]*/, :package => /[^\/]*/
  match 'build/:project/:repository/:arch/:package/_buildinfo' => 'build#buildinfo', 
    :project => /[^\/]*/, :repository => /[^\/]*/, :package => /[^\/]*/
  match 'build/:project/:repository/:arch/:package/_history' => 'build#index',
    :project => /[^\/]*/, :repository => /[^\/]*/, :package => /[^\/]*/
  match 'build/:project/:repository/:arch/:package/:filename' => 'build#file', 
    :project => /[^\/]*/, :repository => /[^\/]*/, :package => /[^\/]*/, :filename => /[^\/]*/
  match 'build/:project/:repository/:arch/_builddepinfo' => 'build#builddepinfo', 
    :project => /[^\/]*/, :repository => /[^\/]*/, :arch => /[^\/]*/
  match 'build/:project/:repository/:arch/:package' => 'build#index',
    :project => /[^\/]*/, :repository => /[^\/]*/, :package => /[^\/]*/
  match 'build/:project/:repository/_buildconfig' => 'build#index',
    :project => /[^\/]*/, :repository => /[^\/]*/
  match 'build/:project/:repository/:arch' => 'build#index', 
    :project => /[^\/]*/, :repository => /[^\/]*/
  match 'build/:project/_result' => 'build#result', :project => /[^\/]*/
  match 'build/:project/:repository' => 'build#index', :project => /[^\/]*/, :repository => /[^\/]*/
  # the web client does no longer use that route, but we keep it for backward compat
  match 'build/_workerstatus' => 'status#workerstatus'
  match 'build/:project' => 'build#project_index', :project => /[^\/]*/
  match 'build' => 'source#index'

  ### /published

  match 'published/:project/:repository/:arch/:binary' => 'published#index', :project => /[^\/]*/, :repository => /[^\/]*/, :binary => /[^\/]*/
  # :arch can be also a ymp for a pattern :/
  match 'published/:project/:repository/:arch' => 'published#index', :project => /[^\/]*/, :repository => /[^\/]*/, :arch => /[^\/]*/
  match 'published/:project/:repository/' => 'published#index', :project => /[^\/]*/, :repository => /[^\/]*/
  match 'published/:project' => 'published#index', :project => /[^\/]*/
  match 'published/' => 'published#index'

  ### /request
  
  resources :request, :only => [:index, :show, :update, :create]
  
  match 'request/:id' => 'request#command'
  # ACL(/search/request) TODO: direct passed call to  'pass_to_backend'
  match 'search/request' => 'request#pass_to_backend'

  ### /lastevents

  match '/lastevents' => 'public#lastevents'


  ### /apidocs

  match 'apidocs/:action' => 'apidocs#(?-mix:[^\/]*)'

  match '/active_rbac/registration/confirm/:user/:token' => 'active_rbac/registration#confirm'


  ### /distributions

  match '/distributions' => 'distribution#index'

  ### /public
    
  match '/public/build/:prj' => 'public#build', :prj => /[^\/]*/
  match '/public/build/:prj/:repo' => 'public#build', :prj => /[^\/]*/, :repo => /[^\/]*/
  match '/public/build/:prj/:repo/:arch/:pkg' => 'public#build', :prj => /[^\/]*/, :repo => /[^\/]*/, :pkg => /[^\/]*/
  match '/public/source/:prj' => 'public#project_index', :prj => /[^\/]*/
  match '/public/source/:prj/_meta' => 'public#project_meta', :prj => /[^\/]*/
  match '/public/source/:prj/_config' => 'public#project_file', :prj => /[^\/]*/
  match '/public/source/:prj/_pubkey' => 'public#project_file', :prj => /[^\/]*/
  match '/public/source/:prj/:pkg' => 'public#package_index', :prj => /[^\/]*/, :pkg => /[^\/]*/
  match '/public/source/:prj/:pkg/_meta' => 'public#package_meta', :prj => /[^\/]*/, :pkg => /[^\/]*/
  match '/public/source/:prj/:pkg/:file' => 'public#source_file', :prj => /[^\/]*/, :pkg => /[^\/]*/, :file => /[^\/]*/
  match '/public/lastevents' => 'public#lastevents'
  match '/public/distributions' => 'public#distributions'
  match '/public/binary_packages/:prj/:pkg' => 'public#binary_packages', :prj => /[^\/]*/, :pkg => /[^\/]*/
  match 'public/status/:action' => 'status#index'

  ### /status
   
  # action request somehow does not work
  match 'status/request/:id' => 'status#request'

  # Install the default route as the lowest priority.
  match '/:controller(/:action(/:id))'
  match ':controller/:action' => '#index'
end
