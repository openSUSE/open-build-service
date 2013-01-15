OBSApi::Application.routes.draw do

  defaults :format => 'xml' do

    match '/' => 'main#index'

    resource :configuration, :only => [:show, :update]

    cons = { :project => %r{[^\/]*}, :package => %r{[^\/]*}, :binary => %r{[^\/]*}, :user => %r{[^\/]*}, :login => %r{[^\/]*}, :title => %r{[^\/]*}, :service => %r{\w[^\/]*},
             :repository => %r{[^\/]*}, :filename => %r{[^\/]*}, :arch => %r{[^\/]*}, :id => %r{\d*} }

    ### /person
    match 'person' => 'person#index'
    # FIXME3.0: this is no clean namespace, a person "register" or "changepasswd" could exist ...
    #           remove these for OBS 3.0
    match 'person/register' => 'person#register'                            # use /person?cmd=register POST instead
    match 'person/changepasswd' => 'person#change_my_password'              # use /person/:login?cmd=changepassword POST instead
    match 'person/:login/group' => 'person#grouplist', :constraints => cons # Use /group?person=:login GET instead
    # /FIXME3.0
    match 'person/:login' => 'person#userinfo', :constraints => cons

    ### /group
    match 'group' => 'group#index'
    match 'group/:title' => 'group#group', :constraints => cons

    ### /service
    match 'service' => 'service#index'
    match 'service/:service' => 'service#index_service', :constraints => cons

    ### /source
    
    match 'source/:project/:package/_wizard' => 'wizard#package_wizard', :constraints => cons
    match 'source/:project/:package/_tags' => 'tag#package_tags', :constraints => cons
    match 'source/:project/_tags' => 'tag#project_tags', :constraints => cons

    match 'about' => 'about#index'

    controller :test do
      match 'test/killme' => :killme
      match 'test/startme' => :startme
      match 'test/test_start' => :test_start
      match 'test/test_end' => :test_end
    end
    
    controller :source do

      match 'source' => :index

      # project level
      match 'source/:project' => :index_project, :constraints => cons
      match 'source/:project/_meta' => :project_meta, :constraints => cons
      match 'source/:project/_attribute' => :attribute_meta, :constraints => cons
      match 'source/:project/_attribute/:attribute' => :attribute_meta, :constraints => cons
      match 'source/:project/_config' => :project_config, :constraints => cons
      match 'source/:project/_pubkey' => :project_pubkey, :constraints => cons

      # package level
      match '/source/:project/:package/_meta' => :package_meta, :constraints => cons
      match 'source/:project/:package/_attribute' => :attribute_meta, :constraints => cons
      match 'source/:project/:package/_attribute/:attribute' => :attribute_meta, :constraints => cons
      match 'source/:project/:package/:binary/_attribute' => :attribute_meta, :constraints =>  cons
      match 'source/:project/:package/:binary/_attribute/:attribute' => :attribute_meta,  :constraints =>  cons
      match 'source/:project/:package/:filename' => :file, :constraints =>  cons
      match 'source/:project/:package' => :index_package, :constraints => cons
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
    controller :tag do
      match 'tag/:tag/_projects' => :get_projects_by_tag
      match 'tag/:tag/_packages' => :get_packages_by_tag
      match 'tag/:tag/_all' => :get_objects_by_tag
      
      #Get a tagcloud including all tags.
      match 'tag/tagcloud' => :tagcloud

      match 'tag/get_tagged_projects_by_user' => :get_tagged_projects_by_user
      match 'tag/get_tagged_packages_by_user' => :get_tagged_packages_by_user
      match 'tag/get_tags_by_user' => :get_tags_by_user
      match 'tag/tags_by_user_and_object' => :tags_by_user_and_object
      match 'tag/get_tags_by_user_and_project' => :get_tags_by_user_and_project
      match 'tag/get_tags_by_user_and_package' => :get_tags_by_user_and_package
      match 'tag/most_popular_tags' => :most_popular_tags
      match 'tag/most_recent_tags' => :most_recent_tags
      match 'tag/get_taglist' => :get_taglist
      match 'tag/project_tags' => :project_tags
      match 'tag/package_tags' => :package_tags

    end


    ### /user

    #Get objects tagged by user. (objects with tags)
    match 'user/:user/tags/_projects' => 'tag#get_tagged_projects_by_user', :constraints => cons
    match 'user/:user/tags/_packages' => 'tag#get_tagged_packages_by_user', :constraints => cons

    #Get tags by user.
    match 'user/:user/tags/_tagcloud' => 'tag#tagcloud', :constraints => cons
      
    #Get tags for a certain object by user.
    match 'user/:user/tags/:project' => 'tag#tags_by_user_and_object', :constraints => cons
    match 'user/:user/tags/:project/:package' => 'tag#tags_by_user_and_object', :constraints => cons

    ### /statistics
    # Routes for statistics
    # ---------------------
    controller :statistics do

      # Download statistics
      #
      match 'statistics/download_counter' => :download_counter

      # Timestamps
      #
      match 'statistics/added_timestamp/:project' => :added_timestamp, :constraints => cons
      match 'statistics/added_timestamp/:project/:package' => :added_timestamp, :constraints => cons
      match 'statistics/updated_timestamp/:project' => :updated_timestamp, :constraints => cons
      match 'statistics/updated_timestamp/:project/:package' => :updated_timestamp, :constraints => cons

      # Ratings
      #
      match 'statistics/rating/:project' => :rating, :constraints => cons
      match 'statistics/rating/:project/:package' => :rating, :constraints => cons
      
      # Activity
      #
      match 'statistics/activity/:project' => :activity, :constraints => cons
      match 'statistics/activity/:project/:package' => :activity, :constraints => cons

      # Newest stats
      #
      match 'statistics/newest_stats' => :newest_stats

      match 'statistics' => :index
      match 'statistics/highest_rated' => :highest_rated
      match 'statistics/download_counter' => :download_counter
      match 'statistics/newest_stats' => :newest_stats
      match 'statistics/most_active_projects' => :most_active_projects
      match 'statistics/most_active_packages' => :most_active_packages
      match 'statistics/latest_added' => :latest_added
      match 'statistics/latest_updated' => :latest_updated
      match 'statistics/global_counters' => :global_counters
      match 'statistics/latest_built' => :latest_built

      match 'statistics/active_request_creators/:project' => :active_request_creators
    end

    ### /status_message

    controller :status do

      # Routes for status_messages
      # --------------------------
      match 'status_message' => 'status#messages'
      
      match 'status/messages' => :messages
      match 'status/messages/:id' => :messages, :constraints => cons
      match 'status/workerstatus' => :workerstatus
      match 'status/history'  => :history
      match 'status/project/:project' => :project, :constraints => cons
      match 'status/bsrequest' => :bsrequest

    end

    ### /message

    # Routes for messages
    # --------------------------
    match 'message/:id' => 'message#index'
    match 'message' => 'message#index'


    ### /search

    controller :search do

      # ACL(/search/published/binary/id) TODO: direct passed call to  "pass_to_backend'
      match 'search/published/binary/id' => :pass_to_backend
      # ACL(/search/published/pattern/id) TODO: direct passed call to  'pass_to_backend'
      match 'search/published/pattern/id'  => :pass_to_backend
      match 'search/project/id' => :project_id
      match 'search/package/id' => :package_id
      match 'search/project_id' => :project_id #FIXME3.0: to be removed
      match 'search/package_id' => :package_id #FIXME3.0: to be removed
      match 'search/project' => :project
      match 'search/package' => :package
      match 'search/attribute' => :attribute
      match 'search/owner' => :owner
      match 'search/missing_owner' => :missing_owner
      match 'search/request' => :bs_request
      match 'search/request/id' => :bs_request_id
      match 'search' => :pass_to_backend

      match 'search/repository/id' => :repository_id
      match 'search/issue' => :issue
      match 'search/attribute' => :attribute

    end

    ### /build

    match 'build/:project/:repository/:arch/:package/_status' => 'build#index',
    :constraints => cons
    match 'build/:project/:repository/:arch/:package/_log' => 'build#logfile', 
    :constraints => cons
    match 'build/:project/:repository/:arch/:package/_buildinfo' => 'build#buildinfo', 
    :constraints => cons
    match 'build/:project/:repository/:arch/:package/_history' => 'build#index',
    :constraints => cons
    match 'build/:project/:repository/:arch/:package/:filename' => 'build#file', 
    :constraints => cons
    match 'build/:project/:repository/:arch/_builddepinfo' => 'build#builddepinfo', 
    :constraints => cons
    match 'build/:project/:repository/:arch/:package' => 'build#index', :constraints => cons
    match 'build/:project/:repository/_buildconfig' => 'build#index', :constraints => cons
    match 'build/:project/:repository/:arch' => 'build#index', :constraints => cons
    match 'build/:project/_result' => 'build#result', :constraints => cons
    match 'build/:project/:repository' => 'build#index', :constraints => cons
    # the web client does no longer use that route, but we keep it for backward compat
    match 'build/_workerstatus' => 'status#workerstatus'
    match 'build/:project' => 'build#project_index', :constraints => cons
    match 'build' => 'source#index'

    ### /published

    match 'published/:project/:repository/:arch/:binary' => 'published#index', :constraints => cons
    # :arch can be also a ymp for a pattern :/
    match 'published/:project/:repository/:arch' => 'published#index', :constraints => cons
    match 'published/:project/:repository/' => 'published#index', :constraints => cons
    match 'published/:project' => 'published#index', :constraints => cons
    match 'published/' => 'published#index'

    ### /request
    
    resources :request, :only => [:index, :show, :update, :create, :destroy]
    
    match 'request/:id' => 'request#command'

    ### /lastevents

    match '/lastevents' => 'public#lastevents'

    ### /distributions

    match '/distributions' => 'distributions#upload', via: :put
    # as long as the distribution IDs are integers, there is no clash
    match '/distributions/include_remotes' => 'distributions#include_remotes', via: :get
    # update is missing here
    resources :distributions, only: [:index, :show, :create, :destroy]

    ### /public
    
    controller :public do
      match 'public' => :index
      match 'public/build/:project' => :build, :constraints => cons
      match 'public/build/:project/:repository' => :build, :constraints => cons
      match 'public/build/:project/:repository/:arch' => :build, :constraints => cons
      match 'public/build/:project/:repository/:arch/:package' => :build, :constraints => cons
      match 'public/source/:project' => :project_index, :constraints => cons
      match 'public/source/:project/_meta' => :project_meta, :constraints => cons
      match 'public/source/:project/_config' => :project_file, :constraints => cons
      match 'public/source/:project/_pubkey' => :project_file, :constraints => cons
      match 'public/source/:project/:package' => :package_index, :constraints => cons
      match 'public/source/:project/:package/_meta' => :package_meta, :constraints => cons
      match 'public/source/:project/:package/:filename' => :source_file, :constraints => cons
      match 'public/lastevents' => :lastevents
      match 'public/distributions' => :distributions
      match 'public/binary_packages/:project/:package' => :binary_packages, :constraints => cons
    end

    match 'public/status/:action' => 'status#index'

    #
    # NOTE: webui routes are NOT stable and change together with the webui.
    #       DO NOT USE THEM IN YOUR TOOLS!
    #
    controller :webui do
      match 'webui/project_infos' => :project_infos
      match 'webui/project_requests' => :project_requests
      match 'webui/project_flags' => :project_flags
      match 'webui/package_flags' => :package_flags
      match 'webui/person_requests_that_need_work' => :person_requests_that_need_work
      match 'webui/request_show' => :request_show
      match 'webui/person_involved_requests' => :person_involved_requests
      match 'webui/request_ids' => :request_ids
      match 'webui/request_list' => :request_list
      match 'webui/change_role' => :change_role, via: :post
      match 'webui/all_projects' => :all_projects
      match 'webui/owner' => :owner
    end

    match "/404" => "main#notfound"

    # Do not install default routes for maximum security
    #match ':controller(/:action(/:id))'
    #match ':controller/:action'

  end
end
