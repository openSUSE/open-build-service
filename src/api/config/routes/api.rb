cons = RoutesHelper::RoutesConstraints::CONS

constraints(RoutesHelper::APIMatcher) do
  get '/', to: redirect('/about')

  resources :about, only: :index

  resource :configuration, only: %i[show update]

  resources :announcements, except: %i[edit new]

  ### /person
  post 'person' => 'person#command'
  get 'person' => 'person#show'
  get 'person/:login/token' => 'person/token#index', constraints: cons
  post 'person/:login/token' => 'person/token#create', constraints: cons
  delete 'person/:login/token/:id' => 'person/token#delete', constraints: cons
  put 'person/:login/token/:id' => 'person/token#update', constraints: cons

  # FIXME3.0: this is no clean namespace, a person "register" or "changepasswd" could exist ...
  #           remove these for OBS 3.0
  match 'person/register' => 'person#register', via: %i[post put] # use /person?cmd=register POST instead
  match 'person/changepasswd' => 'person#change_my_password', via: %i[post put] # use /person/:login?cmd=changepassword POST instead
  get 'person/:login/group' => 'person#grouplist', constraints: cons # Use /group?person=:login GET instead

  ### notifications
  get '/my/notifications' => 'person/notifications#index'
  put '/my/notifications/:id' => 'person/notifications#update'

  # /FIXME3.0
  get 'person/:login' => 'person#userinfo', constraints: cons
  put 'person/:login' => 'person#put_userinfo', constraints: cons
  post 'person/:login' => 'person#post_userinfo', constraints: cons
  get 'person/:login/watchlist' => 'person#watchlist', constraints: cons
  put 'person/:login/watchlist' => 'person#put_watchlist', constraints: cons

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

  ### /source
  controller :attribute_namespace do
    get 'attribute' => :index
    get 'attribute/:namespace' => :index
    # FIXME3.0: drop the POST and DELETE here
    get 'attribute/:namespace/_meta' => :show
    delete 'attribute/:namespace/_meta' => :delete
    delete 'attribute/:namespace' => :delete
    match 'attribute/:namespace/_meta' => :update, via: %i[post put]
  end

  controller :attribute do
    get 'attribute/:namespace/:name/_meta' => :show
    delete 'attribute/:namespace/:name/_meta' => :delete
    delete 'attribute/:namespace/:name' => :delete
    match 'attribute/:namespace/:name/_meta' => :update, via: %i[post put]
  end

  ### /architecture
  resources :architectures, only: %i[index show update] # create,delete currently disabled

  ### /trigger
  post 'trigger' => 'trigger#create'
  post 'trigger/webhook' => 'trigger#create'
  post 'trigger/rebuild' => 'trigger#rebuild'
  post 'trigger/release' => 'trigger#release'
  post 'trigger/runservice' => 'trigger#runservice'
  post 'trigger/workflow' => 'trigger_workflow#create'

  ### /issue_trackers
  resources :issue_trackers, only: %i[index show create update destroy], param: :name do
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

    # Activity
    #
    get 'statistics/activity/:project(/:package)' => :activity, constraints: cons

    get 'statistics' => :index
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
  resources :status_messages, only: %i[show index update create destroy], path: 'status/messages'

  resources :status_project, only: [:show], param: :project, path: 'status/project'

  get 'status_message' => 'status_messages#index'
  get 'status/workerstatus' => 'worker/status#index'

  ### /search

  controller :search do
    match 'search/published/binary/id' => :pass_to_backend, via: %i[get post]
    match 'search/published/repoinfo/id' => :pass_to_backend, via: %i[get post]
    match 'search/published/pattern/id' => :pass_to_backend, via: %i[get post]
    match 'search/channel/binary/id' => :channel_binary_id, via: %i[get post]
    match 'search/channel/binary' => :channel_binary, via: %i[get post]
    match 'search/channel' => :channel, via: %i[get post]
    match 'search/released/binary/id' => :released_binary_id, via: %i[get post]
    match 'search/released/binary' => :released_binary, via: %i[get post]
    match 'search/project/id' => :project_id, via: %i[get post]
    match 'search/package/id' => :package_id, via: %i[get post]
    match 'search/project_id' => :project_id_deprecated, via: %i[get post] # FIXME3.0: to be removed
    match 'search/package_id' => :package_id_deprecated, via: %i[get post] # FIXME3.0: to be removed
    match 'search/project' => :project, via: %i[get post]
    match 'search/package' => :package, via: %i[get post]
    match 'search/person' => :person, via: %i[get post]
    match 'search/owner' => :owner, via: %i[get post]
    match 'search/missing_owner' => :missing_owner, via: %i[get post]
    match 'search/request' => :bs_request, via: %i[get post]
    match 'search/request/id' => :bs_request_id, via: %i[get post]
    match 'search' => :pass_to_backend, via: %i[get post]

    match 'search/repository/id' => :repository_id, via: %i[get post]
    match 'search/issue' => :issue, via: %i[get post]
  end

  ### /request

  resources :request, only: %i[index show create update destroy]

  post 'request/:id' => 'request#request_command', constraints: cons

  ### /lastevents

  get '/lastevents' => 'source#lastevents_public'
  match 'public/lastevents' => 'source#lastevents_public', via: %i[get post]
  post '/lastevents' => 'source#lastevents'

  ### /distributions

  resources :distributions, except: %i[new edit] do
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

  ### /cloud/upload

  scope :cloud, as: :cloud do
    resources :upload, only: %i[index show create destroy], controller: 'cloud/upload_jobs'
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
    get 'public/source/:project/_keyinfo' => :project_file, constraints: cons
    get 'public/source/:project/_pubkey' => :project_file, constraints: cons
    get 'public/source/:project/:package' => :package_index, constraints: cons
    get 'public/source/:project/:package/_meta' => :package_meta, constraints: cons
    get 'public/source/:project/:package/:filename' => :source_file, constraints: cons
    get 'public/distributions' => :distributions
    get 'public/binary_packages/:project/:package' => :binary_packages, constraints: cons
    get 'public/build/:project(/:repository(/:arch(/:package(/:filename))))' => 'public#build', constraints: cons, as: :public_build
    get 'public/image_templates' => :image_templates, constraints: cons
  end

  resources :image_templates, constraints: cons, only: [:index], controller: 'webui/image_templates'
end

# StagingWorkflow API
resources :staging, only: [], param: 'workflow_project', module: 'staging', constraints: cons do
  resource :workflow, only: %i[create destroy update], constraints: cons
  resources :backlog, only: [:index]
  resources :staging_projects, only: %i[index create], param: :name, constraints: cons do
    get '' => :show
    post 'copy/:staging_project_copy_name' => :copy
    post :accept

    get 'staged_requests' => 'staged_requests#index', constraints: cons
    resource :staged_requests, only: %i[create destroy]
  end
  delete 'staged_requests' => :destroy, constraints: cons, controller: 'staged_requests'

  resources :excluded_requests, only: [:index], constraints: cons
  resource :excluded_requests, only: %i[create destroy], constraints: cons
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
  get 'source' => :index
  # FIXME: Why is this not in PublishedController#index?
  get 'published' => :index
  # FIXME: Why is this not in BuildController#index?
  get 'build' => :index
  get 'source/:project' => :show, constraints: cons
  delete 'source/:project' => :delete, constraints: cons
  get 'source/:project/_pubkey' => :show_pubkey, constraints: cons
  delete 'source/:project/_pubkey' => :delete_pubkey, constraints: cons
end

controller :source_project_command do
  post 'source/:project' => :project_command, constraints: cons
end

controller :source_project_config do
  get 'source/:project/_config' => :show, constraints: cons
  put 'source/:project/_config' => :update, constraints: cons
end

controller :source_project_keyinfo do
  get 'source/:project/_keyinfo' => :show, constraints: cons
end

# FIXME: This route only exists because SourcePackageMetaController can't deal with `_project` as package name
controller :source_package do
  get '/source/:project/_project/:filename' => :show_file, constraints: cons, defaults: { format: 'xml' }
end

controller :source_package_meta do
  get 'source/:project/:package/_meta' => :show, constraints: cons
  put 'source/:project/:package/_meta' => :update, constraints: cons
end

controller :source_package_command do
  constraints(cons) do
    post 'source/:project/:package' => :updatepatchinfo, constraints: ->(req) { req.params[:cmd] == 'updatepatchinfo' }
    post 'source/:project/:package' => :importchannel, constraints: ->(req) { req.params[:cmd] == 'importchannel' }
    post 'source/:project/:package' => :unlock, constraints: ->(req) { req.params[:cmd] == 'unlock' }
    post 'source/:project/:package' => :addchannels, constraints: ->(req) { req.params[:cmd] == 'addchannels' }
    post 'source/:project/:package' => :addcontainers, constraints: ->(req) { req.params[:cmd] == 'addcontainers' }
    post 'source/:project/:package' => :enablechannel, constraints: ->(req) { req.params[:cmd] == 'enablechannel' }
    post 'source/:project/:package' => :getprojectservices, constraints: ->(req) { req.params[:cmd] == 'getprojectservices' }
    post 'source/:project/:package' => :showlinked, constraints: ->(req) { req.params[:cmd] == 'showlinked' }
    post 'source/:project/:package' => :collectbuildenv, constraints: ->(req) { req.params[:cmd] == 'collectbuildenv' }
    post 'source/:project/:package' => :instantiate, constraints: ->(req) { req.params[:cmd] == 'instantiate' }
    post 'source/:project/:package' => :undelete, constraints: ->(req) { req.params[:cmd] == 'undelete' }
    post 'source/:project/:package' => :createSpecFileTemplate, constraints: ->(req) { req.params[:cmd] == 'createSpecFileTemplate' }
    post 'source/:project/:package' => :rebuild, constraints: ->(req) { req.params[:cmd] == 'rebuild' }
    post 'source/:project/:package' => :commit, constraints: ->(req) { req.params[:cmd] == 'commit' }
    post 'source/:project/:package' => :commitfilelist, constraints: ->(req) { req.params[:cmd] == 'commitfilelist' }
    post 'source/:project/:package' => :diff, constraints: ->(req) { req.params[:cmd] == 'diff' }
    post 'source/:project/:package' => :linkdiff, constraints: ->(req) { req.params[:cmd] == 'linkdiff' }
    post 'source/:project/:package' => :servicediff, constraints: ->(req) { req.params[:cmd] == 'servicediff' }
    post 'source/:project/:package' => :copy, constraints: ->(req) { req.params[:cmd] == 'copy' }
    post 'source/:project/:package' => :release, constraints: ->(req) { req.params[:cmd] == 'release' }
    post 'source/:project/:package' => :waitservice, constraints: ->(req) { req.params[:cmd] == 'waitservice' }
    post 'source/:project/:package' => :mergeservice, constraints: ->(req) { req.params[:cmd] == 'mergeservice' }
    post 'source/:project/:package' => :runservice, constraints: ->(req) { req.params[:cmd] == 'runservice' }
    post 'source/:project/:package' => :deleteuploadrev, constraints: ->(req) { req.params[:cmd] == 'deleteuploadrev' }
    post 'source/:project/:package' => :linktobranch, constraints: ->(req) { req.params[:cmd] == 'linktobranch' }
    post 'source/:project/:package' => :branch, constraints: ->(req) { req.params[:cmd] == 'branch' }
    post 'source/:project/:package' => :fork, constraints: ->(req) { req.params[:cmd] == 'fork' }
    post 'source/:project/:package' => :set_flag, constraints: ->(req) { req.params[:cmd] == 'set_flag' }
    post 'source/:project/:package' => :remove_flag, constraints: ->(req) { req.params[:cmd] == 'remove_flag' }
  end
end

controller :source_command do
  post 'source' => :global_command_createmaintenanceincident, constraints: ->(req) { req.params[:cmd] == 'createmaintenanceincident' }
  post 'source' => :global_command_branch,                    constraints: ->(req) { req.params[:cmd] == 'branch' }
  post 'source' => :global_command_orderkiwirepos,            constraints: ->(req) { req.params[:cmd] == 'orderkiwirepos' }
  post 'public/source' => :global_command_triggerscmsync,     constraints: ->(req) { req.params[:cmd] == 'triggerscmsync' }
end

controller :source_package do
  get 'source/:project/:package/:filename' => :show_file, constraints: cons, defaults: { format: 'xml' }
  delete 'source/:project/:package/:filename' => :delete_file, constraints: cons
  put 'source/:project/:package/:filename' => :update_file, constraints: cons

  get 'source/:project/:package' => :show, constraints: cons
  delete 'source/:project/:package' => :delete, constraints: cons
end

scope module: :status, path: :status_reports do
  resources :projects, only: [], param: :name, constraints: cons do
    resources :required_checks, only: %i[index create destroy], param: :name
  end

  scope :repositories do
    resources :projects, only: [], param: :name, path: '', constraints: cons do
      resources :repositories, only: [], param: :name, path: '', constraints: cons do
        resources :required_checks, only: %i[index create destroy], param: :name
      end
    end
  end

  scope :built_repositories do
    resources :projects, only: [], param: :name, path: '', constraints: cons do
      resources :repositories, only: [], param: :name, path: '', constraints: cons do
        resources :architectures, only: [], param: :name, path: '', constraints: cons do
          resources :required_checks, only: %i[index create destroy], param: :name
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
    get 'comment/:id/history' => :history, constraints: cons

    delete 'comment/:id' => :destroy, constraints: cons, as: :comment_delete
  end
end

### /assignments
scope :assignments do
  resources :projects, only: [], param: :name do
    resources :assignments, only: [:index], path: '', constraints: cons
    resources :packages, only: [], param: :name do
      resource :assignment, only: %i[create destroy], path: '', constraints: cons
    end
  end
end

# ### /labels
scope :labels do
  resources :projects, only: [], param: :name do
    resources :labels, only: %i[index create destroy], path: '', controller: 'labels/projects', constraints: cons
    resources :packages, only: [], param: :name do
      resources :labels, only: %i[index create destroy], path: '', constraints: cons
    end
  end
  resources :requests, only: [], param: :number do
    resources :labels, only: %i[index create destroy], path: '', constraints: cons
  end
end

### /label_templates
resources :label_templates, only: %i[index create update destroy], constraints: cons

### /label_templates/projects/:project_name(/:id)
scope :label_templates do
  resources :projects, only: [], param: :name do
    resources :label_templates, only: %i[index create update destroy], path: '', controller: 'label_templates/projects', constraints: cons
  end
end

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
match 'build/:project/:repository/:arch/:package/_buildinfo' => 'build#buildinfo', constraints: cons, via: %i[get post]
match 'build/:project/:repository/:arch/:package/_status' => 'build#index', constraints: cons, via: %i[get post]
match 'build/:project/:repository/:arch/:package/_history' => 'build#index', constraints: cons, via: %i[get post]
get 'build/:project/:repository/:arch/:package/:filename' => 'build/file#show', constraints: cons
put 'build/:project/:repository/:arch/:package/:filename' => 'build/file#update', constraints: cons
delete 'build/:project/:repository/:arch/:package/:filename' => 'build/file#destroy', constraints: cons
match 'build/:project/:repository/:arch/_builddepinfo' => 'build#builddepinfo', via: %i[get post], constraints: cons
get 'build/:project/:repository/_buildconfig' => 'build#index', constraints: cons
match 'build/:project/:repository/:arch/:package' => 'build#index', constraints: cons, via: %i[get post]
get 'build/:project/:repository/:arch' => 'build#index', constraints: cons
get 'build/_result' => 'build#scmresult', constraints: cons
get 'build/:project/_result' => 'build#result', constraints: cons
get 'build/:project/:repository' => 'build#index', constraints: cons
match 'build/:project' => 'build#project_index', constraints: cons, via: %i[get post put]

### /published

# :arch can be also a ymp for a pattern :/
get 'published/:project(/:repository(/:arch(/:binary)))' => 'published#index', constraints: cons
