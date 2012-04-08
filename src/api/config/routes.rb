OBSApi::Application.routes.draw do

  defaults :format => 'xml' do

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
    match 'person/:login/group' => 'person#grouplist', :constraints => { :login => /[^\/]*/ }

    match 'person/:login' => 'person#userinfo', :constraints => { :login => /[^\/]*/ }

    ### /group
    match 'group' => 'group#index'
    match 'group/:title' => 'group#show', :constraints => { :title => /[^\/]*/ }

    ### /service
    match 'service/:service' => 'service#index_service', :constraints => { :service => /\w[^\/]*/ }

    ### /source
    
    match 'source/:project/:package/_wizard' => 'wizard#package_wizard', :constraints => { :project => /[^\/]*/, :package => /[^\/]*/ }
    match 'source/:project/:package/_tags' => 'tag#package_tags', :constraints => { :project => /[^\/]*/, :package => /[^\/]*/ }
    match 'source/:project/_tags' => 'tag#project_tags', :constraints => { :project => /[^\/]*/ }
      
    controller :admin do
      match 'admin' => 'admin#index', :defaults => { :format => 'html' }
      match 'admin/:action', :defaults => { :format => 'html' }
      match 'admin(/:action(/:id))', :defaults => { :format => 'html' }
    end
    
    controller :source do

      pcons = { :project => /[^\/]*/, :package => /[^\/]*/ }

      # project level
      match 'source/:project' => :index_project, :constraints => pcons
      match 'source/:project/_meta' => :project_meta, :constraints => pcons
      match 'source/:project/_webui_flags' => :project_flags, :constraints => pcons
      match 'source/:project/_attribute' => :attribute_meta, :constraints => pcons
      match 'source/:project/_attribute/:attribute' => :attribute_meta, :constraints => pcons
      match 'source/:project/_config' => :project_config, :constraints => pcons
      match 'source/:project/_pubkey' => :project_pubkey, :constraints => pcons

      pcons = { :project => /[^\/]*/, :package => /[^\/]*/ }

      # package level
      match '/source/:project/:package/_meta' => :package_meta, :constraints => pcons
      match 'source/:project/:package/_webui_flags' => :package_flags, :constraints => pcons
      match 'source/:project/:package/_attribute' => :attribute_meta, :constraints => pcons
      match 'source/:project/:package/_attribute/:attribute' => :attribute_meta, :constraints => pcons
      match 'source/:project/:package/:binary/_attribute' => :attribute_meta, :constraints =>  pcons.merge(:binary => /[^\/]*/)
      match 'source/:project/:package/:binary/_attribute/:attribute' => :attribute_meta, 
      :constraints =>  pcons.merge(:binary => /[^\/]*/)
      match 'source/:project/:package/:file' => :file, 
      :constraints =>  pcons.merge(:file => /[^\/]*/)
      match 'source/:project/:package' => :index_package, :constraints => pcons
    end

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
    match 'user/:user/tags/_projects' => 'tag#get_tagged_projects_by_user', :constraints => { :user => /[^\/]*/ }
    match 'user/:user/tags/_packages' => 'tag#get_tagged_packages_by_user', :constraints => { :user => /[^\/]*/ }

    #Get tags by user.
    match 'user/:user/tags/_tagcloud' => 'tag#tagcloud', :constraints => { :user => /[^\/]*/ }
      
    #Get tags for a certain object by user.
    match 'user/:user/tags/:project' => 'tag#tags_by_user_and_object', :constraints => {  :project => /[^\/]*/, :user => /[^\/]*/ }
    match 'user/:user/tags/:project/:package' => 'tag#tags_by_user_and_object', :constraints => { :project => /[^\/]*/, :package => /[^\/]*/, :user => /[^\/]*/ }

    ### /statistics
    # Routes for statistics
    # ---------------------

    # Download statistics
    #
    match 'statistics/download_counter' => 'statistics#download_counter'

    # Timestamps
    #
    match 'statistics/added_timestamp/:project' => 'statistics#added_timestamp', :constraints => { :project => /[^\/]*/ }
    match 'statistics/added_timestamp/:project/:package' => 'statistics#added_timestamp', 
    :constraints => {  :project => /[^\/]*/, :package => /[^\/]*/ }
    match 'statistics/updated_timestamp/:project' => 'statistics#updated_timestamp', :constraints => { :project => /[^\/]*/ }
    match 'statistics/updated_timestamp/:project/:package' => 'statistics#updated_timestamp',
    :constraints => { :project => /[^\/]*/, :package => /[^\/]*/ }

    # Ratings
    #
    match 'statistics/rating/:project' => 'statistics#rating', :constraints => { :project => /[^\/]*/ }
    match 'statistics/rating/:project/:package' => 'statistics#rating', :constraints => { :project => /[^\/]*/, :package => /[^\/]*/ }

    # Activity
    #
    match 'statistics/activity/:project' => 'statistics#activity', :constraints => { :project => /[^\/]*/ }
    match 'statistics/activity/:project/:package' => 'statistics#activity', :constraints => { :project => /[^\/]*/, :package => /[^\/]*/ }

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
    :constraints => { :project => /[^\/]*/, :repository => /[^\/]*/, :package => /[^\/]*/ }
    match 'build/:project/:repository/:arch/:package/_log' => 'build#logfile', 
    :constraints => { :project => /[^\/]*/, :repository => /[^\/]*/, :package => /[^\/]*/ }
    match 'build/:project/:repository/:arch/:package/_buildinfo' => 'build#buildinfo', 
    :constraints => { :project => /[^\/]*/, :repository => /[^\/]*/, :package => /[^\/]*/ }
    match 'build/:project/:repository/:arch/:package/_history' => 'build#index',
    :constraints => { :project => /[^\/]*/, :repository => /[^\/]*/, :package => /[^\/]*/ }
    match 'build/:project/:repository/:arch/:package/:filename' => 'build#file', 
    :constraints => { :project => /[^\/]*/, :repository => /[^\/]*/, :package => /[^\/]*/, :filename => /[^\/]*/ }
    match 'build/:project/:repository/:arch/_builddepinfo' => 'build#builddepinfo', 
    :constraints => { :project => /[^\/]*/, :repository => /[^\/]*/, :arch => /[^\/]*/ }
    match 'build/:project/:repository/:arch/:package' => 'build#index',
    :constraints => { :project => /[^\/]*/, :repository => /[^\/]*/, :package => /[^\/]*/ }
    match 'build/:project/:repository/_buildconfig' => 'build#index',
    :constraints => { :project => /[^\/]*/, :repository => /[^\/]*/ }
    match 'build/:project/:repository/:arch' => 'build#index', 
    :constraints => { :project => /[^\/]*/, :repository => /[^\/]*/ }
    match 'build/:project/_result' => 'build#result', :constraints => { :project => /[^\/]*/ }
    match 'build/:project/:repository' => 'build#index', :constraints => { :project => /[^\/]*/, :repository => /[^\/]*/ }
    # the web client does no longer use that route, but we keep it for backward compat
    match 'build/_workerstatus' => 'status#workerstatus'
    match 'build/:project' => 'build#project_index', :constraints => { :project => /[^\/]*/ }
    match 'build' => 'source#index'

    ### /published

    match 'published/:project/:repository/:arch/:binary' => 'published#index', :constraints => { :project => /[^\/]*/, :repository => /[^\/]*/, :binary => /[^\/]*/ }
    # :arch can be also a ymp for a pattern :/
    match 'published/:project/:repository/:arch' => 'published#index', :constraints => { :project => /[^\/]*/, :repository => /[^\/]*/, :arch => /[^\/]*/ }
    match 'published/:project/:repository/' => 'published#index', :constraints => { :project => /[^\/]*/, :repository => /[^\/]*/ }
    match 'published/:project' => 'published#index', :constraints => { :project => /[^\/]*/ }
    match 'published/' => 'published#index'

    ### /request
    
    resources :request, :only => [:index, :show, :update, :create]
    
    match 'request/:id' => 'request#command'
    # ACL(/search/request) TODO: direct passed call to  'pass_to_backend'
    match 'search/request' => 'request#pass_to_backend'

    ### /lastevents

    match '/lastevents' => 'public#lastevents'

    ### /apidocs

    match 'apidocs' => 'apidocs#index'
    match 'apidocs/:file' => 'apidocs#file', :constraints => { :file => /[^\/]*/ }

    match '/active_rbac/registration/confirm/:user/:token' => 'active_rbac/registration#confirm'


    ### /distributions

    match '/distributions' => 'distribution#index'

    ### /public
    
    match '/public/build/:prj' => 'public#build', :constraints => { :prj => /[^\/]*/ }
    match '/public/build/:prj/:repo' => 'public#build', :constraints => { :prj => /[^\/]*/, :repo => /[^\/]*/ }
    match '/public/build/:prj/:repo/:arch/:pkg' => 'public#build', :constraints => { :prj => /[^\/]*/, :repo => /[^\/]*/, :pkg => /[^\/]*/ }
    match '/public/source/:prj' => 'public#project_index', :constraints => { :prj => /[^\/]*/ }
    match '/public/source/:prj/_meta' => 'public#project_meta', :constraints => { :prj => /[^\/]*/ }
    match '/public/source/:prj/_config' => 'public#project_file', :constraints => { :prj => /[^\/]*/ }
    match '/public/source/:prj/_pubkey' => 'public#project_file', :constraints => { :prj => /[^\/]*/ }
    match '/public/source/:prj/:pkg' => 'public#package_index', :constraints => { :prj => /[^\/]*/, :pkg => /[^\/]*/ }
    match '/public/source/:prj/:pkg/_meta' => 'public#package_meta', :constraints => { :prj => /[^\/]*/, :pkg => /[^\/]*/ }
    match '/public/source/:prj/:pkg/:file' => 'public#source_file', :constraints => {  :prj => /[^\/]*/, :pkg => /[^\/]*/, :file => /[^\/]*/ }
    match '/public/lastevents' => 'public#lastevents'
    match '/public/distributions' => 'public#distributions'
    match '/public/binary_packages/:prj/:pkg' => 'public#binary_packages', :constraints => { :prj => /[^\/]*/, :pkg => /[^\/]*/ }
    match 'public/status/:action' => 'status#index'

    ### /status
    
    # action request somehow does not work
    match 'status/request/:id' => 'status#request'
    match 'status/project/:id' => 'status#project', :constraints => { :id => /[^\/]*/ }

    match "/404" => "main#notfound"

    # Install the default route as the lowest priority.
    match '/:controller(/:action(/:id))'
    match ':controller/:action'

  end
end
