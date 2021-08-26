OBSApi::Application.routes.draw do
  cons = RoutesHelper::RoutesConstraints::CONS

  constraints(RoutesHelper::APIMatcher) do
    get '/', to: redirect('/about')

    resources :about, only: :index

    resource :configuration, only: [:show, :update]

    resources :announcements, except: [:edit, :new]

    ### /person
    post 'person' => 'person#command'
    get 'person' => 'person#show'
    get 'person/:login/token' => 'person/token#index', constraints: cons
    post 'person/:login/token' => 'person/token#create', constraints: cons
    delete 'person/:login/token/:id' => 'person/token#delete', constraints: cons

    # FIXME3.0: this is no clean namespace, a person "register" or "changepasswd" could exist ...
    #           remove these for OBS 3.0
    match 'person/register' => 'person#register', via: [:post, :put] # use /person?cmd=register POST instead
    match 'person/changepasswd' => 'person#change_my_password', via: [:post, :put] # use /person/:login?cmd=changepassword POST instead
    get 'person/:login/group' => 'person#grouplist', constraints: cons # Use /group?person=:login GET instead
    # /FIXME3.0
    get 'person/:login' => 'person#get_userinfo', constraints: cons
    put 'person/:login' => 'person#put_userinfo', constraints: cons
    post 'person/:login' => 'person#post_userinfo', constraints: cons

    ### /group
    controller :group do
      get 'group' => :index
      get 'group/:title' => :show, constraints: cons
      delete 'group/:title' => :delete, constraints: cons
      put 'group/:title' => :update, constraints: cons
      post 'group/:title' => :command, constraints: cons
    end

    ### /service
    get 'service' => 'service#index'
    get 'service/:service' => 'service#index_service', constraints: cons

    ### /source
    get 'source/:project/_keyinfo' => 'source/key_info#show', constraints: cons

    controller :attribute_namespace do
      get 'attribute' => :index
      get 'attribute/:namespace' => :index
      # FIXME3.0: drop the POST and DELETE here
      get 'attribute/:namespace/_meta' => :show
      delete 'attribute/:namespace/_meta' => :delete
      delete 'attribute/:namespace' => :delete
      match 'attribute/:namespace/_meta' => :update, via: [:post, :put]
    end

    controller :attribute do
      get 'attribute/:namespace/:name/_meta' => :show
      delete 'attribute/:namespace/:name/_meta' => :delete
      delete 'attribute/:namespace/:name' => :delete
      match 'attribute/:namespace/:name/_meta' => :update, via: [:post, :put]
    end

    ### /architecture
    resources :architectures, only: [:index, :show, :update] # create,delete currently disabled

    ### /trigger
    post 'trigger/rebuild' => 'trigger#create'
    post 'trigger/release' => 'trigger#create'
    post 'trigger/runservice' => 'trigger#create'
    post 'trigger/webhook' => 'trigger#create'
    post 'trigger/workflow' => 'trigger_workflow#create'

    ### /issue_trackers
    resources :issue_trackers, only: [:index, :show, :create, :update, :destroy], param: :name do
      resources :issues, only: [:show]
    end

    ### /statistics
    # Routes for statistics
    # ---------------------
    controller :statistics do
      # Timestamps
      #
      get 'statistics/added_timestamp/:project(/:package)' => :added_timestamp, constraints: cons
      get 'statistics/updated_timestamp/:project(/:package)' => :updated_timestamp, constraints: cons

      # Ratings
      #
      get 'statistics/rating/:project(/:package)' => :rating, constraints: cons

      # Activity
      #
      get 'statistics/activity/:project(/:package)' => :activity, constraints: cons

      get 'statistics' => :index
      get 'statistics/highest_rated' => :highest_rated
      get 'statistics/most_active_projects' => :most_active_projects
      get 'statistics/most_active_packages' => :most_active_packages
      get 'statistics/latest_added' => :latest_added
      get 'statistics/latest_updated' => :latest_updated
      get 'statistics/global_counters' => :global_counters

      get 'statistics/active_request_creators/:project' => :active_request_creators, constraints: cons
      get 'statistics/maintenance_statistics/:project' => 'statistics/maintenance_statistics#index', constraints: cons,
          as: 'maintenance_statistics'
      get 'public/statistics/maintenance_statistics/:project' => 'statistics/maintenance_statistics#index', constraints: cons
    end

    ### /status_message
    resources :status_messages, only: [:show, :index, :create, :destroy], path: 'status/messages'

    resources :status_project, only: [:show], param: :project, path: 'status/project'

    get 'status_message' => 'status_messages#index'
    get 'status/workerstatus' => 'worker/status#index'

    ### /message

    # Routes for messages
    # --------------------------
    controller :message do
      put 'message' => :update
      get 'message' => :list
      get 'message/:id' => :show
      delete 'message/:id' => :delete
    end

    ### /search

    controller :search do
      match 'search/published/binary/id' => :pass_to_backend, via: [:get, :post]
      match 'search/published/repoinfo/id' => :pass_to_backend, via: [:get, :post]
      match 'search/published/pattern/id' => :pass_to_backend, via: [:get, :post]
      match 'search/channel/binary/id' => :channel_binary_id, via: [:get, :post]
      match 'search/channel/binary' => :channel_binary, via: [:get, :post]
      match 'search/channel' => :channel, via: [:get, :post]
      match 'search/released/binary/id' => :released_binary_id, via: [:get, :post]
      match 'search/released/binary' => :released_binary, via: [:get, :post]
      match 'search/project/id' => :project_id, via: [:get, :post]
      match 'search/package/id' => :package_id, via: [:get, :post]
      match 'search/project_id' => :project_id, via: [:get, :post] # FIXME3.0: to be removed
      match 'search/package_id' => :package_id, via: [:get, :post] # FIXME3.0: to be removed
      match 'search/project' => :project, via: [:get, :post]
      match 'search/package' => :package, via: [:get, :post]
      match 'search/person' => :person, via: [:get, :post]
      match 'search/owner' => :owner, via: [:get, :post]
      match 'search/missing_owner' => :missing_owner, via: [:get, :post]
      match 'search/request' => :bs_request, via: [:get, :post]
      match 'search/request/id' => :bs_request_id, via: [:get, :post]
      match 'search' => :pass_to_backend, via: [:get, :post]

      match 'search/repository/id' => :repository_id, via: [:get, :post]
      match 'search/issue' => :issue, via: [:get, :post]
    end

    ### /request

    resources :request, only: [:index, :show, :update, :destroy]

    post 'request' => 'request#global_command'
    post 'request/:id' => 'request#request_command', constraints: cons

    ### /lastevents

    get '/lastevents' => 'source#lastevents_public'
    match 'public/lastevents' => 'source#lastevents_public', via: [:get, :post]
    post '/lastevents' => 'source#lastevents'

    ### /distributions

    resources :distributions, except: [:new, :edit] do
      collection do
        get 'include_remotes'
        put 'bulk_replace' => :bulk_replace
        # This GET routes gives us a poor mans osc interface for bulk replacing...
        # Like: osc api -e /distributions/bulk_replace
        get 'bulk_replace' => :index
        # This PUT route is for backward compatiblity, it was traditionally
        # used for bulk replacing distributions.
        put '' => :bulk_replace
      end
    end

    ### /mail_handler

    put '/mail_handler' => 'mail_handler#upload'

    ### /cloud/upload

    scope :cloud, as: :cloud do
      resources :upload, only: [:index, :show, :create, :destroy], controller: 'cloud/upload_jobs'
    end

    ### /public
    controller :public do
      get 'public', to: redirect('/public/about')
      get 'public/about' => 'about#index'
      get 'public/configuration' => :configuration_show
      get 'public/configuration.xml' => :configuration_show
      get 'public/request/:number' => :show_request, constraints: cons
      get 'public/source/:project' => :project_index, constraints: cons
      get 'public/source/:project/_meta' => :project_meta, constraints: cons
      get 'public/source/:project/_config' => :project_file, constraints: cons
      get 'public/source/:project/_pubkey' => :project_file, constraints: cons
      get 'public/source/:project/:package' => :package_index, constraints: cons
      get 'public/source/:project/:package/_meta' => :package_meta, constraints: cons
      get 'public/source/:project/:package/:filename' => :source_file, constraints: cons
      get 'public/distributions' => :distributions
      get 'public/binary_packages/:project/:package' => :binary_packages, constraints: cons
      get 'public/build/:project(/:repository(/:arch(/:package(/:filename))))' => 'public#build', constraints: cons, as: :public_build
    end

    scope 'public' do
      resources :image_templates, constraints: cons, only: [:index], controller: 'webui/image_templates'
    end

    resources :image_templates, constraints: cons, only: [:index], controller: 'webui/image_templates'

    ### /projects
    get 'projects/:project/requests' => 'webui/projects/bs_requests#index', constraints: cons, as: 'projects_requests'
    get 'projects/:project/packages/:package/requests' => 'webui/packages/bs_requests#index', constraints: cons, as: 'packages_requests'
  end

  # StagingWorkflow API
  resources :staging, only: [], param: 'workflow_project', module: 'staging', constraints: cons do
    resource :workflow, only: [:create, :destroy, :update], constraints: cons
    resources :backlog, only: [:index]
    resources :staging_projects, only: [:index, :create], param: :name, constraints: cons do
      get '' => :show
      post 'copy/:staging_project_copy_name' => :copy
      post :accept

      get 'staged_requests' => 'staged_requests#index', constraints: cons
      resource :staged_requests, only: [:create, :destroy]
    end
    delete 'staged_requests' => :destroy, constraints: cons, controller: 'staged_requests'

    resources :excluded_requests, only: [:index], constraints: cons
    resource :excluded_requests, only: [:create, :destroy], constraints: cons
  end

  controller :source_attribute do
    get 'source/:project(/:package(/:binary))/_attribute(/:attribute)' => :show, constraints: cons
    post 'source/:project(/:package(/:binary))/_attribute(/:attribute)' => :update, constraints: cons, as: :change_attribute
    delete 'source/:project(/:package(/:binary))/_attribute/:attribute' => :delete, constraints: cons
  end

  # project level
  controller :source_project_meta do
    get 'source/:project/_meta' => :show, constraints: cons
    put 'source/:project/_meta' => :update, constraints: cons
  end

  controller :source_project do
    get 'source/:project' => :show, constraints: cons
    delete 'source/:project' => :delete, constraints: cons
    post 'source/:project' => :project_command, constraints: cons
  end

  controller :source_project_config do
    get 'source/:project/_config' => :show, constraints: cons
    put 'source/:project/_config' => :update, constraints: cons
  end

  controller :source do
    # package level
    get '/source/:project/_project/:filename' => :get_file, constraints: cons, defaults: { format: 'xml' }
  end

  controller :source_project_package_meta do
    get 'source/:project/:package/_meta' => :show, constraints: cons
    put 'source/:project/:package/_meta' => :update, constraints: cons
  end

  controller :source do
    get 'source' => :index
    post 'source' => :global_command_createmaintenanceincident, constraints: ->(req) { req.params[:cmd] == 'createmaintenanceincident' }
    post 'source' => :global_command_branch,                    constraints: ->(req) { req.params[:cmd] == 'branch' }
    post 'source' => :global_command_orderkiwirepos,            constraints: ->(req) { req.params[:cmd] == 'orderkiwirepos' }
    get 'source/:project/_pubkey' => :show_project_pubkey, constraints: cons
    delete 'source/:project/_pubkey' => :delete_project_pubkey, constraints: cons

    get 'source/:project/:package/:filename' => :get_file, constraints: cons, defaults: { format: 'xml' }
    delete 'source/:project/:package/:filename' => :delete_file, constraints: cons
    put 'source/:project/:package/:filename' => :update_file, constraints: cons

    get 'source/:project/:package' => :show_package, constraints: cons
    post 'source/:project/:package' => :package_command, constraints: cons
    delete 'source/:project/:package' => :delete_package, constraints: cons
  end

  scope module: :status, path: :status_reports do
    resources :projects, only: [], param: :name, constraints: cons do
      resources :required_checks, only: [:index, :create, :destroy], param: :name
    end

    scope :repositories do
      resources :projects, only: [], param: :name, path: '', constraints: cons do
        resources :repositories, only: [], param: :name, path: '', constraints: cons do
          resources :required_checks, only: [:index, :create, :destroy], param: :name
        end
      end
    end

    scope :built_repositories do
      resources :projects, only: [], param: :name, path: '', constraints: cons do
        resources :repositories, only: [], param: :name, path: '', constraints: cons do
          resources :architectures, only: [], param: :name, path: '', constraints: cons do
            resources :required_checks, only: [:index, :create, :destroy], param: :name
          end
        end
      end
    end

    controller :reports do
      scope :published do
        get ':project_name/:repository_name/reports/:report_uuid' => :show, constraints: cons
      end
      scope :built do
        get ':project_name/:repository_name/:arch/reports/:report_uuid' => :show, constraints: cons
      end
      scope :requests do
        get ':bs_request_number/reports' => :show
      end
    end
    controller :checks do
      scope :published do
        post ':project_name/:repository_name/reports/:report_uuid' => :update, constraints: cons
      end
      scope :built do
        post ':project_name/:repository_name/:arch/reports/:report_uuid' => :update, constraints: cons
      end
      scope :requests do
        post ':bs_request_number/reports' => :update
      end
    end
  end

  defaults format: 'xml' do
    controller :comments do
      get 'comments/request/:request_number' => :index, constraints: cons, as: :comments_request
      post 'comments/request/:request_number' => :create, constraints: cons, as: :create_request_comment
      get 'comments/package/:project/:package' => :index, constraints: cons, as: :comments_package
      post 'comments/package/:project/:package' => :create, constraints: cons, as: :create_package_comment
      get 'comments/project/:project' => :index, constraints: cons, as: :comments_project
      post 'comments/project/:project' => :create, constraints: cons, as: :create_project_comment
      get 'comments/user' => :index, constraints: cons, as: :comments_user

      delete 'comment/:id' => :destroy, constraints: cons, as: :comment_delete
    end
  end

  # this can be requested by non browsers (like HA proxies :)
  get 'apidocs/:filename' => 'webui/apidocs#file', constraints: cons, as: 'apidocs_file'

  # spiders request this, not browsers
  controller 'webui/sitemaps' do
    get 'sitemaps' => :index
    get 'project/sitemap' => :projects
    get 'package/sitemap(/:project_name)' => :packages
  end

  scope :worker, as: :worker do
    resources :status, only: [:index], controller: 'worker/status'
    resources :capability, only: [:show], param: :worker, controller: 'worker/capability'
    resources :command, only: [], controller: 'worker/command' do
      collection do
        post 'run'
      end
    end
  end

  ### /worker
  get 'worker/_status' => 'worker/status#index', as: :worker_status
  get 'build/_workerstatus' => 'worker/status#index', as: :build_workerstatus # For backward compatibility
  get 'worker/:worker' => 'worker/capability#show'
  post 'worker' => 'worker/command#run'

  ### /build
  get 'build/:project/:repository/:arch/:package/_log' => 'build#logfile', constraints: cons, as: :raw_logfile
  match 'build/:project/:repository/:arch/:package/_buildinfo' => 'build#buildinfo', constraints: cons, via: [:get, :post]
  match 'build/:project/:repository/:arch/:package/_status' => 'build#index', constraints: cons, via: [:get, :post]
  match 'build/:project/:repository/:arch/:package/_history' => 'build#index', constraints: cons, via: [:get, :post]
  get 'build/:project/:repository/:arch/:package/:filename' => 'build/file#show', constraints: cons
  put 'build/:project/:repository/:arch/:package/:filename' => 'build/file#update', constraints: cons
  delete 'build/:project/:repository/:arch/:package/:filename' => 'build/file#destroy', constraints: cons
  match 'build/:project/:repository/:arch/_builddepinfo' => 'build#builddepinfo', via: [:get, :post], constraints: cons
  match 'build/:project/:repository/_buildconfig' => 'build#index', constraints: cons, via: [:get, :post]
  match 'build/:project/:repository/:arch(/:package)' => 'build#index', constraints: cons, via: [:get, :post]
  get 'build/:project/_result' => 'build#result', constraints: cons
  match 'build/:project/:repository' => 'build#index', constraints: cons, via: [:get, :post]
  match 'build/:project' => 'build#project_index', constraints: cons, via: [:get, :post, :put]
  get 'build' => 'source#index'

  ### /published

  # :arch can be also a ymp for a pattern :/
  get 'published/:project(/:repository(/:arch(/:binary)))' => 'published#index', constraints: cons
  get 'published/' => 'source#index', via: :get
end
