OBSApi::Application.routes.draw do

  defaults :format => 'xml' do

    get '/' => 'main#index'

    resource :configuration, :only => [:show, :update, :schedulers]

    cons = { :project => %r{[^\/]*}, :package => %r{[^\/]*}, :binary => %r{[^\/]*}, :user => %r{[^\/]*}, :login => %r{[^\/]*}, :title => %r{[^\/]*}, :service => %r{\w[^\/]*},
             :repository => %r{[^\/]*}, :filename => %r{[^\/]*}, :arch => %r{[^\/]*}, :id => %r{\d*} }

    ### /person
    match 'person' => 'person#index', via: [:get, :post]
    # FIXME3.0: this is no clean namespace, a person "register" or "changepasswd" could exist ...
    #           remove these for OBS 3.0
    match 'person/register' => 'person#register', via: [:post, :put]      # use /person?cmd=register POST instead
    match 'person/changepasswd' => 'person#change_my_password', via: [:post, :put]     # use /person/:login?cmd=changepassword POST instead
    get 'person/:login/group' => 'person#grouplist', :constraints => cons # Use /group?person=:login GET instead
    # /FIXME3.0
    match 'person/:login' => 'person#userinfo', :constraints => cons, via: [:get, :put, :post]

    ### /group
    controller :group do
      get 'group' => :index
      get 'group/:title' => :show
      delete 'group/:title' => :delete
      put 'group/:title' => :update
      post 'group/:title' => :command
    end

    ### /service
    get 'service' => 'service#index'
    get 'service/:service' => 'service#index_service', :constraints => cons

    ### /source
    
    get 'source/:project/:package/_wizard' => 'wizard#package_wizard', :constraints => cons
    get 'source/:project/:package/_tags' => 'tag#package_tags', :constraints => cons
    get 'source/:project/_tags' => 'tag#project_tags', :constraints => cons

    get 'about' => 'about#index'

    controller :test do
      post 'test/killme' => :killme
      post 'test/startme' => :startme
      post 'test/test_start' => :test_start
      post 'test/prepare_search' => :prepare_search
    end

    ### /attribute is before source as it needs more specific routes for projects
    controller :attribute do
      get 'attribute' => :index
      get 'attribute/:namespace' => :index
      match 'attribute/:namespace/_meta' =>  :namespace_definition, via: [:get, :delete, :post]
      match 'attribute/:namespace/:name/_meta' => :attribute_definition, via: [:get, :delete, :post]

      get 'source/:project(/:package(/:binary))/_attribute(/:attribute)' => :show_attribute, :constraints => cons
      post 'source/:project(/:package(/:binary))/_attribute(/:attribute)' => :cmd_attribute, :constraints => cons
      delete 'source/:project(/:package(/:binary))/_attribute(/:attribute)' => :delete_attribute, :constraints => cons
    end

    controller :source do

      get 'source' => :index
      post 'source' => :global_command

      # project level
      get 'source/:project' => :show_project, constraints: cons
      delete 'source/:project' => :delete_project, constraints: cons
      post 'source/:project' => :project_command, constraints: cons
      match 'source/:project/_meta' => :project_meta, :constraints => cons, via: [:get, :put]

      match 'source/:project/_config' => :project_config, :constraints => cons, via: [:get, :put]
      match 'source/:project/_pubkey' => :project_pubkey, :constraints => cons, via: [:get, :delete]

      # package level 
      match '/source/:project/:package/_meta' => :package_meta, :constraints => cons, via: [:get, :put]

      get 'source/:project/:package/:filename' => :get_file, constraints: cons
      delete 'source/:project/:package/:filename' => :delete_file, constraints: cons
      put 'source/:project/:package/:filename' => :update_file, constraints: cons

      get 'source/:project/:package' => :show_package, constraints: cons
      post 'source/:project/:package' => :package_command, constraints: cons
      delete 'source/:project/:package' => :delete_package, constraints: cons
    end

    ### /architecture
    resources :architectures, :only => [:index, :show, :update] # create,delete currently disabled

    ### /issue_trackers
    get 'issue_trackers/issues_in' => 'issue_trackers#issues_in'
    resources :issue_trackers, :only => [:index, :show, :create, :update, :destroy] do
      resources :issues, :only => [:show] # Nested route
    end

    ### /tag

    #routes for tagging support
    #
    # get 'tag/_all' => 'tag',
    #  :action => 'list_xml'
    #Get/put tags by object
    ### moved to source section

    #Get objects by tag.
    controller :tag do
      get 'tag/:tag/_projects' => :get_projects_by_tag
      get 'tag/:tag/_packages' => :get_packages_by_tag
      get 'tag/:tag/_all' => :get_objects_by_tag
      
      #Get a tagcloud including all tags.
      match 'tag/tagcloud' => :tagcloud, via: [:get, :post]

      get 'tag/get_tagged_projects_by_user' => :get_tagged_projects_by_user
      get 'tag/get_tagged_packages_by_user' => :get_tagged_packages_by_user
      get 'tag/get_tags_by_user' => :get_tags_by_user
      get 'tag/tags_by_user_and_object' => :tags_by_user_and_object
      get 'tag/get_tags_by_user_and_project' => :get_tags_by_user_and_project
      get 'tag/get_tags_by_user_and_package' => :get_tags_by_user_and_package
      get 'tag/most_popular_tags' => :most_popular_tags
      get 'tag/most_recent_tags' => :most_recent_tags
      get 'tag/get_taglist' => :get_taglist
      get 'tag/project_tags' => :project_tags
      get 'tag/package_tags' => :package_tags

    end


    ### /user

    #Get objects tagged by user. (objects with tags)
    get 'user/:user/tags/_projects' => 'tag#get_tagged_projects_by_user', :constraints => cons
    get 'user/:user/tags/_packages' => 'tag#get_tagged_packages_by_user', :constraints => cons

    #Get tags by user.
    get 'user/:user/tags/_tagcloud' => 'tag#tagcloud', :constraints => cons
      
    #Get tags for a certain object by user.
    match 'user/:user/tags/:project' => 'tag#tags_by_user_and_object', :constraints => cons, via: [:get, :post, :put, :delete]
    match 'user/:user/tags/:project/:package' => 'tag#tags_by_user_and_object', :constraints => cons, via: [:get, :post, :put, :delete]

    ### /statistics
    # Routes for statistics
    # ---------------------
    controller :statistics do

      # Download statistics
      #
      get 'statistics/download_counter' => :download_counter

      # Timestamps
      #
      get 'statistics/added_timestamp/:project' => :added_timestamp, :constraints => cons
      get 'statistics/added_timestamp/:project/:package' => :added_timestamp, :constraints => cons
      get 'statistics/updated_timestamp/:project' => :updated_timestamp, :constraints => cons
      get 'statistics/updated_timestamp/:project/:package' => :updated_timestamp, :constraints => cons

      # Ratings
      #
      get 'statistics/rating/:project' => :rating, :constraints => cons
      get 'statistics/rating/:project/:package' => :rating, :constraints => cons
      
      # Activity
      #
      get 'statistics/activity/:project' => :activity, :constraints => cons
      get 'statistics/activity/:project/:package' => :activity, :constraints => cons

      # Newest stats
      #
      get 'statistics/newest_stats' => :newest_stats

      get 'statistics' => :index
      get 'statistics/highest_rated' => :highest_rated
      get 'statistics/download_counter' => :download_counter
      get 'statistics/newest_stats' => :newest_stats
      get 'statistics/most_active_projects' => :most_active_projects
      get 'statistics/most_active_packages' => :most_active_packages
      get 'statistics/latest_added' => :latest_added
      get 'statistics/latest_updated' => :latest_updated
      get 'statistics/global_counters' => :global_counters
      get 'statistics/latest_built' => :latest_built

      get 'statistics/active_request_creators/:project' => :active_request_creators
    end

    ### /status_message

    controller :status do

      # Routes for status_messages
      # --------------------------
      get 'status_message' => 'status#messages'
      
      match 'status/messages' => :messages, via: [:get, :put]
      match 'status/messages/:id' => :messages, :constraints => cons, via: [:get, :delete]
      get 'status/workerstatus' => :workerstatus
      get 'status/history'  => :history
      get 'status/project/:project' => :project, :constraints => cons
      get 'status/bsrequest' => :bsrequest

    end

    ### /message

    # Routes for messages
    # --------------------------
    match 'message/:id' => 'message#index', via: [:get, :delete, :put]
    match 'message' => 'message#index', via: [:get, :put]


    ### /search

    controller :search do

      # ACL(/search/published/binary/id) TODO: direct passed call to  "pass_to_backend'
      match 'search/published/binary/id' => :pass_to_backend, via: [:get, :post]
      # ACL(/search/published/pattern/id) TODO: direct passed call to  'pass_to_backend'
      match 'search/published/pattern/id'  => :pass_to_backend, via: [:get, :post]
      match 'search/project/id' => :project_id, via: [:get, :post]
      match 'search/package/id' => :package_id, via: [:get, :post]
      match 'search/project_id' => :project_id, via: [:get, :post] #FIXME3.0: to be removed
      match 'search/package_id' => :package_id, via: [:get, :post] #FIXME3.0: to be removed
      match 'search/project' => :project, via: [:get, :post]
      match 'search/package' => :package, via: [:get, :post]
      match 'search/person' => :person, via: [:get, :post]
      match 'search/attribute' => :attribute, via: [:get, :post]
      match 'search/owner' => :owner, via: [:get, :post]
      match 'search/missing_owner' => :missing_owner, via: [:get, :post]
      match 'search/request' => :bs_request, via: [:get, :post]
      match 'search/request/id' => :bs_request_id, via: [:get, :post]
      match 'search' => :pass_to_backend, via: [:get, :post]

      match 'search/repository/id' => :repository_id, via: [:get, :post]
      match 'search/issue' => :issue, via: [:get, :post]
      match 'search/attribute' => :attribute, via: [:get, :post]

    end

    ### /build

    match 'build/:project/:repository/:arch/:package/_status' => 'build#index', :constraints => cons, via: [:get, :post]
    get 'build/:project/:repository/:arch/:package/_log' => 'build#logfile', :constraints => cons
    match 'build/:project/:repository/:arch/:package/_buildinfo' => 'build#buildinfo', :constraints => cons, via: [:get, :post]
    match 'build/:project/:repository/:arch/:package/_history' => 'build#index', :constraints => cons, via: [:get, :post]
    match 'build/:project/:repository/:arch/:package/:filename' => 'build#file', via: [:get, :put, :delete], :constraints => cons
    get 'build/:project/:repository/:arch/_builddepinfo' => 'build#builddepinfo', :constraints => cons
    match 'build/:project/:repository/:arch/:package' => 'build#index', :constraints => cons, via: [:get, :post]
    match 'build/:project/:repository/_buildconfig' => 'build#index', :constraints => cons, via: [:get, :post]
    match 'build/:project/:repository/:arch' => 'build#index', :constraints => cons, via: [:get, :post]
    get 'build/:project/_result' => 'build#result', :constraints => cons
    match 'build/:project/:repository' => 'build#index', :constraints => cons, via: [:get, :post]
    # the web client does no longer use that route, but we keep it for backward compat
    get 'build/_workerstatus' => 'status#workerstatus'
    match 'build/:project' => 'build#project_index', :constraints => cons, via: [:get, :post, :put]
    get 'build' => 'source#index'

    ### /published

    get 'published/:project/:repository/:arch/:binary' => 'published#index', :constraints => cons
    # :arch can be also a ymp for a pattern :/
    get 'published/:project/:repository/:arch' => 'published#index', :constraints => cons
    get 'published/:project/:repository/' => 'published#index', :constraints => cons
    get 'published/:project' => 'published#index', :constraints => cons
    get 'published/' => 'source#index', via: :get

    ### /request
    
    resources :request, :only => [:index, :show, :update, :create, :destroy]
    
    match 'request/:id' => 'request#command', via: [:post, :get]

    ### /lastevents

    get '/lastevents' => 'source#lastevents_public'
    match 'public/lastevents' => "source#lastevents_public", via: [:get, :post]
    post '/lastevents' => 'source#lastevents'

    ### /distributions

    put '/distributions' => 'distributions#upload'
    # as long as the distribution IDs are integers, there is no clash
    get '/distributions/include_remotes' => 'distributions#include_remotes'
    # update is missing here
    resources :distributions, only: [:index, :show, :create, :destroy]

    ### /public
    
    controller :public do
      get 'public' => :index
      get 'public/build/:project' => :build, :constraints => cons
      get 'public/build/:project/:repository' => :build, :constraints => cons
      get 'public/build/:project/:repository/:arch' => :build, :constraints => cons
      get 'public/build/:project/:repository/:arch/:package' => :build, :constraints => cons
      get 'public/source/:project' => :project_index, :constraints => cons
      get 'public/source/:project/_meta' => :project_meta, :constraints => cons
      get 'public/source/:project/_config' => :project_file, :constraints => cons
      get 'public/source/:project/_pubkey' => :project_file, :constraints => cons
      get 'public/source/:project/:package' => :package_index, :constraints => cons
      get 'public/source/:project/:package/_meta' => :package_meta, :constraints => cons
      get 'public/source/:project/:package/:filename' => :source_file, :constraints => cons
      get 'public/distributions' => :distributions
      get 'public/binary_packages/:project/:package' => :binary_packages, :constraints => cons
    end

    get 'public/configuration' => 'configurations#show'
    get 'public/configuration.json' => 'configurations#show'
    get 'public/configuration.xml' => 'configurations#show'
    get 'public/status/:action' => 'status#index'

    #
    # NOTE: webui routes are NOT stable and change together with the webui.
    #       DO NOT USE THEM IN YOUR TOOLS!
    #
    namespace :webui do
      resources :projects, :only => [:index], :constraints => { :id => %r{[^\/]*} } do
        member do
          get "infos"
          get "status"
        end
        resources :relationships, :only => [:create] do
          collection do
            delete :for_user, action: :remove_user
          end
        end
        resources :flags, :only => [:index]
        resources :packages, :only => [], :constraints => { :id => %r{[^\/]*} } do
          resources :relationships, :only => [:create] do
            collection do
              delete :for_user, action: :remove_user
            end
          end
          resources :flags, :only => [:index]
        end
      end
      resources :packages, :only => [], :constraints => { :id => %r{[^\/]*} } do
        get "flags", :on => :member
      end
      resources :requests, :only => [:index, :show] do
        collection do
          get :ids
          get :by_class
        end
      end
      resources :owners, :only => [:index]
      resources :searches, :only => [:new, :create]
      resources :attrib_types, :only => [:index]

      # comments
      get 'comments/request/:id/' => 'comments#requests', constraints: cons
      get 'comments/package/:project/:package/' => 'comments#packages', constraints: cons
      get 'comments/project/:project/' => 'comments#projects', constraints: cons
      
      post 'comments/project/:project/new' => 'comments#projects_new', constraints: cons
      post 'comments/package/:project/:package/new' => 'comments#packages_new', constraints: cons
      post 'comments/request/:id/new' => 'comments#requests_new', constraints: cons

      post 'comments/project/:project/delete' => 'comments#delete', constraints: cons
      post 'comments/package/:project/:package/delete' => 'comments#delete', constraints: cons
      post 'comments/request/:id/delete' => 'comments#delete', constraints: cons

    end

    get "/404" => "main#notfound"

    # Do not install default routes for maximum security
    #get ':controller(/:action(/:id))'
    #get ':controller/:action'

  end
end
