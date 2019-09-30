OBSApi::Application.routes.draw do
  cons = RoutesContrains::CONS

  constraints(APIMatcher) do
    get '/' => 'main#index'

    resource :configuration, only: [:show, :update, :schedulers]

    resources :announcements, except: [:edit, :new]

    ### /person
    post 'person' => 'person#command'
    get 'person' => 'person#show'
    post 'person/:login/login' => 'person#login', constraints: cons # temporary hack for webui, do not use, to be removed
    get 'person/:login/token' => 'person/token#index', constraints: cons
    post 'person/:login/token' => 'person/token#create', constraints: cons
    delete 'person/:login/token/:id' => 'person/token#delete', constraints: cons

    # FIXME3.0: this is no clean namespace, a person "register" or "changepasswd" could exist ...
    #           remove these for OBS 3.0
    match 'person/register' => 'person#register', via: [:post, :put] # use /person?cmd=register POST instead
    match 'person/changepasswd' => 'person#change_my_password', via: [:post, :put] # use /person/:login?cmd=changepassword POST instead
    get 'person/:login/group' => 'person#grouplist', constraints: cons # Use /group?person=:login GET instead
    # /FIXME3.0
    match 'person/:login' => 'person#get_userinfo', constraints: cons, via: [:get]
    match 'person/:login' => 'person#put_userinfo', constraints: cons, via: [:put]
    match 'person/:login' => 'person#post_userinfo', constraints: cons, via: [:post]

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

    get 'source/:project/:package/_tags' => 'tag#package_tags', constraints: cons
    get 'source/:project/_tags' => 'tag#project_tags', constraints: cons
    get 'source/:project/_keyinfo' => 'source/key_info#show', constraints: cons

    resources :about, only: :index

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
    post 'trigger/rebuild' => 'trigger#rebuild'
    post 'trigger/release' => 'trigger#release'
    post 'trigger/runservice' => 'trigger#runservice'
    post 'trigger/webhook' => 'services/webhooks#create'

    ### /issue_trackers
    get 'issue_trackers/issues_in' => 'issue_trackers#issues_in'
    resources :issue_trackers, only: [:index, :show, :create, :update, :destroy] do
      resources :issues, only: [:show] # Nested route
    end

    ### /tag

    # routes for tagging support
    #
    # get 'tag/_all' => 'tag',
    #  action: 'list_xml'
    # Get/put tags by object
    ### moved to source section

    # Get objects by tag.
    controller :tag do
      get 'tag/:tag/_projects' => :get_projects_by_tag
      get 'tag/:tag/_packages' => :get_packages_by_tag
      get 'tag/:tag/_all' => :get_objects_by_tag

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

    # Get objects tagged by user. (objects with tags)
    get 'user/:user/tags/_projects' => 'tag#get_tagged_projects_by_user', constraints: cons
    get 'user/:user/tags/_packages' => 'tag#get_tagged_packages_by_user', constraints: cons

    # Get tags for a certain object by user.
    match 'user/:user/tags/:project(/:package)' => 'tag#tags_by_user_and_object', constraints: cons, via: [:get, :post, :put, :delete]

    ### /statistics
    # Routes for statistics
    # ---------------------
    controller :statistics do
      # Download statistics
      #
      get 'statistics/download_counter' => :download_counter

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

      # Newest stats
      #
      get 'statistics/newest_stats' => :newest_stats

      get 'statistics' => :index
      get 'statistics/highest_rated' => :highest_rated
      get 'statistics/most_active_projects' => :most_active_projects
      get 'statistics/most_active_packages' => :most_active_packages
      get 'statistics/latest_added' => :latest_added
      get 'statistics/latest_updated' => :latest_updated
      get 'statistics/global_counters' => :global_counters
      get 'statistics/latest_built' => :latest_built

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
      # ACL(/search/published/binary/id) TODO: direct passed call to  "pass_to_backend'
      match 'search/published/binary/id' => :pass_to_backend, via: [:get, :post]
      # ACL(/search/published/pattern/id) TODO: direct passed call to  'pass_to_backend'
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
      match 'search/attribute' => :attribute, via: [:get, :post]
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

    put '/distributions' => 'distributions#upload'
    # as long as the distribution IDs are integers, there is no clash
    get '/distributions/include_remotes' => 'distributions#include_remotes'
    # update is missing here
    resources :distributions, only: [:index, :show, :create, :destroy]

    ### /mail_handler

    put '/mail_handler' => 'mail_handler#upload'

    ### /cloud/upload

    scope :cloud, as: :cloud do
      resources :upload, only: [:index, :show, :create, :destroy], controller: 'cloud/upload_jobs'
    end

    ### /public
    controller :public do
      get 'public' => :index
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

    get '/404' => 'main#notfound'

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
    resources :staging_projects, only: [:index, :show, :create], param: :name, constraints: cons do
      post 'copy/:staging_project_copy_name' => :copy
      post :accept

      get 'staged_requests' => 'staged_requests#index'
      resource :staged_requests, only: [:create, :destroy]
    end

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
end
