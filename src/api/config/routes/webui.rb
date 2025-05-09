cons = RoutesHelper::RoutesConstraints::CONS

constraints(RoutesHelper::WebuiMatcher) do
  root 'webui/main#index'

  constraints(RoutesHelper::RoleMatcher) do
    mount Flipper::UI.app(Flipper) => '/flipper'
  end

  resources :news_items, only: %i[index new create edit update destroy], controller: 'webui/status_messages' do
    collection do
      post 'preview'
    end
  end

  controller 'webui/feeds' do
    get 'main/news' => :news, constraints: ->(req) { req.format == :rss }, as: :news_feed
    get 'main/latest_updates' => :latest_updates, constraints: ->(req) { req.format == :rss }, as: :latest_updates_feed
    get 'project/latest_commits/:project' => :commits, defaults: { format: 'atom' }, constraints: cons, as: 'commits_feed'
    get 'user/feed/:secret' => :notifications, defaults: { format: 'rss' }, as: :user_rss_notifications
  end

  resources :attribs, constraints: cons, only: %i[create update destroy], controller: 'webui/attribute' do
    collection do
      get ':project(/:package)/new' => :new, constraints: cons, as: 'new'
      get ':project(/:package)/:attribute/edit' => :edit, constraints: cons, as: 'edit'
      get ':project(/:package)' => :index, constraints: cons, as: 'index', defaults: { format: 'html' }
    end
  end

  resources :image_templates, constraints: cons, only: [:index], controller: 'webui/image_templates'

  resources :download_repositories, constraints: cons, only: %i[create update destroy], controller: 'webui/download_on_demand'

  controller 'webui/configuration' do
    get 'configuration' => :index
    patch 'configuration' => :update
  end
  resources :interconnects, only: %i[new create], controller: 'webui/interconnects'

  controller 'webui/subscriptions' do
    get 'notifications' => :index
    put 'notifications' => :update
  end

  controller 'webui/architectures' do
    patch 'architectures/bulk_update_availability' => :bulk_update_availability, as: :bulk_update_availability
  end

  resources :architectures, only: %i[index update], controller: 'webui/architectures'

  resources :label_templates, controller: 'webui/label_templates', constraints: cons

  controller 'webui/monitor' do
    get 'monitor/' => :index
    get 'monitor/old' => :old
    get 'monitor/update_building' => :update_building
    get 'monitor/events' => :events, as: :monitor_events
  end

  resources :package, only: [:index], controller: 'webui/package', constraints: cons

  controller 'webui/packages/build_log' do
    get 'package/live_build_log/:project/:package/:repository/:arch' => :live_build_log, constraints: cons, as: 'package_live_build_log'
    defaults format: 'js' do
      get 'package/update_build_log/:project/:package/:repository/:arch' => :update_build_log, constraints: cons, as: 'package_update_build_log'
    end
  end

  controller 'webui/package' do
    defaults format: 'js' do
      get 'package/edit/:project/:package' => :edit, constraints: cons, as: 'edit_package'
      patch 'package/update' => :update, constraints: cons
      get 'package/autocomplete' => :autocomplete
    end
  end

  defaults format: 'html' do
    controller 'webui/package' do
      get 'package/show/:project/:package' => :show, as: 'package_show', constraints: cons
      get 'package/branch_diff_info/:project/:package' => :branch_diff_info, as: 'package_branch_diff_info', constraints: cons
      # For backward compatibility
      get 'package/binary/:project/:package/:repository/:arch/:filename', to: redirect('/projects/%{project}/packages/%{package}/repositories/%{repository}/%{arch}/%{filename}'),
                                                                          constraints: cons
      # For backward compatibility
      get 'package/binaries/:project/:package/:repository', to: redirect('/projects/%{project}/packages/%{package}/repositories/%{repository}'), constraints: cons
      get 'package/users/:project/:package' => :users, as: 'package_users', constraints: cons
      get 'package/requests/:project/:package' => :requests, as: 'package_requests', constraints: cons
      get 'package/statistics/:project/:package/:repository/:arch' => :statistics, as: 'package_statistics', constraints: cons
      get 'package/revisions/:project/:package' => :revisions, constraints: cons, as: 'package_view_revisions'
      get 'package/rdiff/:project/:package' => :rdiff, constraints: cons, as: 'package_rdiff'
      post 'package/create/:project' => :create, constraints: cons, as: 'packages'
      get 'package/new/:project' => :new, constraints: cons, as: 'new_package'
      post 'package/remove/:project/:package' => :remove, constraints: cons
      # For backward compatibility
      get 'package/view_file/:project/:package/:filename', to: redirect('/projects/%{project}/packages/%{package}/files/%{filename}'), constraints: cons
      get 'package/devel_project/:project/:package' => :devel_project, constraints: cons, as: 'package_devel_project'
      get 'package/buildresult' => :buildresult, constraints: cons, as: 'package_buildresult'
      get 'package/rpmlint_result' => :rpmlint_result, constraints: cons, as: 'rpmlint_result'
      get 'package/rpmlint_log' => :rpmlint_log, constraints: cons
      # For backward compatibility
      get 'package/meta/:project/:package', to: redirect('/projects/%{project}/packages/%{package}/meta'), constraints: cons
      # For backward compatibility
      get 'package/attributes/:project/:package', to: redirect('/attribs/%{project}/%{package}'), constraints: cons
      # For backward compatibility
      get 'package/repositories/:project/:package', to: redirect('/repositories/%{project}/%{package}'), constraints: cons
      # For backward compatibility
      get 'package/files/:project/:package' => :show, constraints: cons
    end
  end

  controller 'webui/package' do
    post 'package/save_person/:project/:package' => :save_person, constraints: cons, as: 'package_save_person'
    post 'package/save_group/:project/:package' => :save_group, constraints: cons, as: 'package_save_group'
    post 'package/remove_role/:project/:package' => :remove_role, constraints: cons, as: 'package_remove_role'
    post 'package/preview_description' => :preview_description, constraints: cons
  end

  resources :packages, only: [], param: :name do
    resource :job_history, controller: 'webui/packages/job_history', only: [] do
      get '/:project/:repository/:arch' => :index, as: :index, constraints: cons
    end

    resource :build_reason, controller: 'webui/packages/build_reason', only: [] do
      get '/:project/:repository/:arch' => :index, as: :index, constraints: cons
    end

    resource :branches, controller: 'webui/packages/branches', only: [] do
      get '/:project', action: :new, as: :new, constraints: cons
    end
  end

  resource :packages, only: [] do
    resources :branches, controller: 'webui/packages/branches', only: [:create], constraints: cons do
      get '/:project', action: :into, on: :new, as: :project, constraints: cons
    end
  end

  resource :patchinfo, except: [:show], controller: 'webui/patchinfo' do
    get 'new_tracker' => :new_tracker
    post 'update_issues/:project/:package' => :update_issues, as: :update_issues
    get 'show/:project/:package' => :show, as: :show, constraints: cons
  end

  controller 'webui/repositories' do
    get 'repositories/:project(/:package)' => :index, constraints: cons, as: 'repositories', defaults: { format: 'html' }
    get 'project/repositories/:project' => :index, constraints: cons, as: 'project_repositories'
    get 'project/add_repository_from_default_list/:project', to: redirect('/projects/%{project}/distributions/new'), constraints: cons
    post 'project/save_repository' => :create
    post 'project/update_target/:project' => :update, constraints: cons
    get 'project/repository_state/:project/:repository' => :state, constraints: cons, as: 'project_repository_state'
    post 'project/remove_target' => :destroy, as: 'destroy_repository'
    post 'project/create_dod_repository' => :create_dod_repository, as: 'create_dod_repository'
    post 'project/create_image_repository' => :create_image_repository

    # Flags
    post 'flag/:project(/:package)' => :change_flag, constraints: cons, as: 'change_repository_flag'
  end

  controller 'webui/kiwi/images' do
    get 'package/:package_id/kiwi_images/import_from_package' => :import_from_package, as: 'import_kiwi_image'
  end

  resources :kiwi_images, only: %i[show edit update], controller: 'webui/kiwi/images' do
    member do
      get 'build_result' => :build_result, constraints: cons
      get 'autocomplete_binaries' => :autocomplete_binaries, as: :autocomplete_binaries
    end
  end

  scope :cloud, as: :cloud do
    resources :configuration, only: [:index], controller: 'webui/cloud/configurations'

    resources :upload, only: %i[index create destroy], controller: 'webui/cloud/upload_jobs' do
      new do
        get ':project/:package/:repository/:arch/:filename', to: 'webui/cloud/upload_jobs#new', as: '', constraints: cons
      end

      resource :log, only: :show, controller: 'webui/cloud/upload_job/logs'
    end
    scope :azure, as: :azure do
      resource :configuration, only: %i[show update destroy], controller: 'webui/cloud/azure/configurations'
      resource :upload, only: [:create], controller: 'webui/cloud/azure/upload_jobs' do
        new do
          get ':project/:package/:repository/:arch/:filename', to: 'webui/cloud/azure/upload_jobs#new', as: '', constraints: cons
        end
      end
    end
    scope :ec2, as: :ec2 do
      resource :configuration, only: %i[show update], controller: 'webui/cloud/ec2/configurations'
      resource :upload, only: [:create], controller: 'webui/cloud/ec2/upload_jobs' do
        new do
          get ':project/:package/:repository/:arch/:filename', to: 'webui/cloud/ec2/upload_jobs#new', as: '', constraints: cons
        end
      end
    end
  end

  controller 'webui/project' do
    get 'project/' => :index, as: 'projects'
    get 'project/list_public' => :index, as: 'project_list_public'
    get 'project/list_all' => :index, show_all: true, as: 'project_list_all'
    get 'project/list' => :index, as: 'project_list'
    get 'project/autocomplete_projects' => :autocomplete_projects, as: 'autocomplete_projects'
    get 'project/autocomplete_staging_projects' => :autocomplete_staging_projects, as: 'autocomplete_staging_projects'
    get 'project/autocomplete_incidents' => :autocomplete_incidents, as: 'autocomplete_incidents'
    get 'project/autocomplete_packages' => :autocomplete_packages, as: 'autocomplete_packages'
    get 'project/autocomplete_repositories' => :autocomplete_repositories, as: 'autocomplete_repositories'
    get 'project/users/:project' => :users, constraints: cons, as: 'project_users'
    get 'project/subprojects/:project' => :subprojects, constraints: cons, as: 'project_subprojects'
    get 'project/attributes/:project', to: redirect('/attribs/%{project}'), constraints: cons
    get 'project/release_request/(:project)' => :release_request, constraints: cons, as: :project_release_request
    post 'project/new_release_request/(:project)' => :new_release_request, constraints: cons, as: :project_new_release_request
    get 'project/show/:project' => :show, constraints: cons, as: 'project_show'
    get 'project/buildresult' => :buildresult, constraints: cons, as: 'project_buildresult'
    get 'project/new' => :new, as: 'new_project'
    get 'project/edit/:project' => :edit, constraints: cons, as: 'edit_project'
    post 'project/create' => :create, constraints: cons, as: 'projects_create'
    post 'project/restore' => :restore, constraints: cons, as: 'projects_restore'
    patch 'project/update' => :update, constraints: cons
    delete 'project/destroy' => :destroy
    get 'project/requests/:project' => :requests, constraints: cons, as: 'project_requests'
    post 'project/remove_target_request' => :remove_target_request, as: 'project_remove_target_request'
    post 'project/remove_path_from_target' => :remove_path_from_target, as: 'remove_repository_path'
    post 'project/move_path/:project' => :move_path, as: 'move_repository_path'
    post 'project/save_person/:project' => :save_person, constraints: cons, as: 'project_save_person'
    post 'project/save_group/:project' => :save_group, constraints: cons, as: 'project_save_group'
    post 'project/remove_role/:project' => :remove_role, constraints: cons, as: 'project_remove_role'
    get 'project/monitor/:project' => :monitor, constraints: cons, as: 'project_monitor'
    # For backward compatibility
    get 'project/monitor', to: redirect { |_path_parameters, request|
      url_string = request.query_parameters.except(:project).to_param
      url_string = '?' << url_string unless url_string.empty?
      "/project/monitor/#{request.query_parameters[:project]}#{url_string}"
    }, constraints: ->(request) { request.query_parameters['project'].present? }
    get 'project/clear_failed_comment/:project' => :clear_failed_comment, constraints: cons, as: :clear_failed_comment
    get 'project/edit_comment_form/:project' => :edit_comment_form, constraints: cons, as: :edit_comment_form
    post 'project/edit_comment/:project' => :edit_comment, constraints: cons
    post 'project/unlock' => :unlock
    post 'project/preview_description' => :preview_description
  end

  # For backward compatibility
  controller 'webui/projects/meta' do
    get 'project/meta/:project', to: redirect('/projects/%{project}/meta')
  end
  controller 'webui/projects/pulse' do
    get 'project/pulse/:project', to: redirect('/projects/%{project}/pulse')
  end
  controller 'webui/projects/rebuild_times' do
    get 'project/rebuild_time/:project/:repository/:arch', to: redirect('/projects/rebuild_time/%{project}/%{repository}/%{arch}')
    get 'project/rebuild_time_png/:project/:key', to: redirect('/projects/rebuild_time_png/%{project}/%{key}')
  end
  controller 'webui/projects/maintenance_incidents' do
    get 'project/maintenance_incidents/:project', to: redirect('/projects/%{project}/maintenance_incidents')
  end
  controller 'webui/projects/project_configuration' do
    get 'project/prjconf/:project', to: redirect('/projects/%{project}/prjconf')
  end
  controller 'webui/projects/signing_keys' do
    get 'project/keys_and_certificates/:project', to: redirect('/projects/%{project}/signing_keys')
    get 'projects/:project/public_key', to: redirect('/projects/%{project}/signing_keys')
    get 'projects/:project/ssl_certificate', to: redirect('/projects/%{project}/signing_keys')
  end
  # \For backward compatibility

  resources :projects, only: [], param: :name do
    resources :maintained_projects, controller: 'webui/projects/maintained_projects',
                                    param: :maintained_project, only: %i[index destroy create], constraints: cons
    resource :status, controller: 'webui/projects/status', only: [:show], constraints: cons
    resource :signing_keys, controller: 'webui/projects/signing_keys', only: [:show], constraints: cons do
      get 'download'
    end
    resource :pulse, controller: 'webui/projects/pulse', only: [:show], constraints: cons
    resource :meta, controller: 'webui/projects/meta', only: %i[show update], constraints: cons
    resource :prjconf, controller: 'webui/projects/project_configuration', only: %i[show update], as: :config, constraints: cons
    resource :rebuild_time, controller: 'webui/projects/rebuild_times', only: [:show], constraints: cons do
      get 'rebuild_time_png'
    end
    resources :maintenance_incidents, controller: 'webui/projects/maintenance_incidents', only: %i[index create], constraints: cons
    resources :maintenance_incident_requests, controller: 'webui/projects/maintenance_incident_requests', only: %i[new create], constraints: cons
    resources :packages, only: [], param: :name do
      resources :role_additions, controller: 'webui/requests/role_additions', only: %i[new create], constraints: cons
      resources :deletions, controller: 'webui/requests/deletions', only: %i[new create], constraints: cons
      resources :devel_project_changes, controller: 'webui/requests/devel_project_changes', only: %i[new create], constraints: cons
      resources :submissions, controller: 'webui/requests/submissions', only: %i[new create], constraints: cons
      resources :files, controller: 'webui/packages/files', only: %i[new create show update destroy], constraints: cons, param: :filename, format: false, defaults: { format: 'html' } do
        get :blame
      end
      put 'toggle_watched_item', controller: 'webui/watched_items', constraints: cons
      resource :badge, controller: 'webui/packages/badge', only: [:show], constraints: cons.merge(format: :svg)
      resources :repositories, only: [], param: :name do
        resources :binaries, controller: 'webui/packages/binaries', only: [:index], constraints: cons
        # Binaries with the exact same name can exist in multiple architectures, so we have to use arch param here additionally
        resources :binaries, controller: 'webui/packages/binaries', only: [:show], constraints: cons, param: :filename, path: 'binaries/:arch/' do
          get :dependency
          get :filelist
        end
        # We wipe all binaries at once, so this is resource instead of resources
        resource :binaries, controller: 'webui/packages/binaries', only: [:destroy], constraints: cons
      end
      resource :meta, controller: 'webui/packages/meta', only: %i[show update], constraints: cons
      resource :trigger, controller: 'webui/packages/trigger', only: [], constraints: cons do
        defaults format: 'js' do
          member do
            post 'rebuild' => :rebuild
            post 'abort_build' => :abort_build
            post 'services' => :services
          end
        end
      end
      resources :assignments, only: %i[create destroy], controller: 'webui/packages/assignments'
    end

    resources :role_additions, controller: 'webui/requests/role_additions', only: %i[new create], constraints: cons
    resources :deletions, controller: 'webui/requests/deletions', only: %i[new create], constraints: cons
    resources :distributions, only: [:new], controller: 'webui/distributions', constraints: cons do
      collection do
        post :toggle
      end
    end
    put 'toggle_watched_item', controller: 'webui/watched_items', constraints: cons
    resource :label_globals, controller: 'webui/projects/label_globals', only: %i[update], constraints: cons
    resources :label_templates, controller: 'webui/projects/label_templates', constraints: cons do
      collection do
        get :copy
        post :clone
        get :preview
      end
    end
  end

  get 'request/show/:number/build_results', to: redirect('/requests/%{number}/build_results'), constraints: cons
  get 'request/show/:number/(request_action/:request_action_id)/build_results', to: redirect('/requests/%{number}/actions/%{request_action_id}/build_results'), constraints: cons
  get 'request/show/:number/rpm_lint', to: redirect('/requests/%{number}/rpm_lint'), constraints: cons
  get 'request/show/:number/(request_action/:request_action_id)/rpm_lint', to: redirect('/requests/%{number}/actions/%{request_action_id}/rpm_lint'), constraints: cons
  get 'request/show/:number/changes', to: redirect('/requests/%{number}/changes'), constraints: cons
  get 'request/show/:number/(request_action/:request_action_id)/changes', to: redirect('/requests/%{number}/actions/%{request_action_id}/changes'), constraints: cons
  get 'request/show/:number/mentioned_issues', to: redirect('/requests/%{number}/mentioned_issues'), constraints: cons
  get 'request/show/:number/(request_action/:request_action_id)/mentioned_issues', to: redirect('/requests/%{number}/actions/%{request_action_id}/mentioned_issues'), constraints: cons

  controller 'webui/request' do
    post 'request/add_reviewer' => :add_reviewer
    post 'request/modify_review' => :modify_review
    get 'request/show/:number/(request_action/:request_action_id)' => :show, as: 'request_show', constraints: cons
    # TODO: Simplify this with `resources` instead after rolling out `:request_show_redesign` feature
    get 'requests/:number/(actions/:request_action_id)' => :beta_show, as: 'request_beta_show', constraints: cons
    get 'requests/:number/(actions/:request_action_id)/build_results' => :build_results, as: 'request_build_results', constraints: cons
    get 'requests/:number/(actions/:request_action_id)/rpm_lint' => :rpm_lint, as: 'request_rpm_lint', constraints: cons
    get 'requests/:number/(actions/:request_action_id)/changes' => :changes, as: 'request_changes', constraints: cons
    get 'requests/:number/actions/:request_action_id/changes/:filename' => :changes_diff, as: 'request_changes_diff', constraints: cons
    get 'requests/:number/(actions/:request_action_id)/mentioned_issues' => :mentioned_issues, as: 'request_mentioned_issues', constraints: cons
    post 'request/sourcediff' => :sourcediff
    post 'request/changerequest' => :changerequest
    get 'request/diff/:number' => :diff
    get 'request/list_small' => :list_small, as: 'request_list_small'
    post 'request/set_bugowner_request' => :set_bugowner_request
    get 'request/:number/request_action/:id' => :request_action, as: 'request_action'
    get 'request/:number/request_action/:id/changes' => :request_action_changes, as: 'request_action_changes'
    get 'request/:number/request_action/:request_action_id/details' => :request_action_details, as: 'request_action_details'
    get 'request/:number/request_action/:request_action_id/inline_comment' => :inline_comment, constraints: cons, as: 'request_inline_comment'
    get 'request/:number/chart_build_results' => :chart_build_results, as: 'request_chart_build_results', constraints: cons
    get 'request/:number/complete_build_results' => :complete_build_results, as: 'request_complete_build_results', constraints: cons
    get 'autocomplete_reviewers' => :autocomplete_reviewers, as: 'autocomplete_reviewers'
  end

  resources :requests, only: [], param: :number, controller: 'webui/request' do
    member do
      put :toggle_watched_item, controller: 'webui/watched_items'
      put :toggle, controller: 'webui/action_seen_by_users'
    end
  end

  get 'projects/:project/requests' => 'webui/projects/bs_requests#index', constraints: cons, as: 'projects_requests'
  get 'projects/:project/packages/:package/requests' => 'webui/packages/bs_requests#index', constraints: cons, as: 'packages_requests'

  controller 'webui/search' do
    get 'search' => :index
    get 'search/owner' => :owner
    get 'search/issue' => :issue
  end

  resources :users, controller: 'webui/users', param: :login, constraints: cons do
    collection do
      get 'autocomplete'
      get 'tokens'
    end
    member do
      put 'censor'
      post 'change_password'
      post 'rss_secret'
      get 'edit_account'
    end
    resource :block, only: %i[create destroy], controller: 'webui/users/block', constraints: cons
  end

  scope :my do
    resources :tasks, only: [:index], controller: 'webui/users/tasks', as: :my_tasks
    resources :requests, only: [:index], controller: 'webui/users/bs_requests', as: :my_requests

    resources :notifications, only: [:index], controller: 'webui/users/notifications', as: :my_notifications do
      collection do
        # We allow updating multiple notifications in a single HTTP request
        put :update
      end
    end

    resources :beta_features, only: [:index], controller: 'webui/users/beta_features', as: :my_beta_features
    resource :beta_feature, only: [:update], controller: 'webui/users/beta_features', as: :my_beta_feature

    resource :notification, only: [:update], controller: 'webui/users/notifications', as: :my_notification

    resources :subscriptions, only: [:index], controller: 'webui/users/subscriptions', as: :my_subscriptions do
      collection do
        put 'update', as: :update
      end
    end

    resources :patchinfos, only: [:index], controller: 'webui/users/patchinfos', as: :my_patchinfos

    post 'news_items/:id' => :acknowledge, controller: 'webui/status_messages', as: :acknowledge_news_item

    resources :tokens, controller: 'webui/users/tokens' do
      resources :workflow_runs, only: %i[index show], controller: 'webui/workflow_runs'
      resources :users, only: %i[index create destroy], controller: 'webui/users/tokens/users', constraints: cons
      resources :groups, only: %i[create destroy], controller: 'webui/users/tokens/groups', constraints: cons
    end

    resources :canned_responses, controller: 'webui/users/canned_responses', only: %i[index create edit update destroy], constraints: cons
  end

  get 'home', to: 'webui/webui#home', as: :home
  get 'signup', to: 'webui/users#new', as: :signup

  # TODO
  # keep those routes reachable, but remove them later as
  # nobody access it anymore
  # Legacy routes start
  namespace :user do
    get '/signup', to: redirect('/signup')
    get '/register_user', to: redirect('/signup')
    get '/show/:user', to: redirect('/users/%{user}'), constraints: cons
    get '/autocomplete', to: redirect('/users/autocomplete')
    get '/tokens', to: redirect('/users/tokens')
  end
  # Legacy routes end

  resource :session, only: %i[new create destroy], controller: 'webui/session'

  resources :groups, only: %i[index show new create edit update], param: :title, constraints: cons, controller: 'webui/groups' do
    resources :user, only: %i[create destroy update], param: :user_login, constraints: cons, controller: 'webui/groups/users'
    resources :requests, only: [:index], controller: 'webui/groups/bs_requests'

    collection do
      get :autocomplete
    end
  end

  resources :comments, constraints: cons, only: %i[create destroy update], controller: 'webui/comments' do
    member do
      post 'moderate'
    end

    defaults format: 'js' do
      get 'history/:version_id' => :history, as: :history
    end

    collection do
      post 'preview'
    end
  end
end

resources :staging_workflows, except: :index, controller: 'webui/staging/workflows', param: :workflow_project, constraints: cons do
  member do
    resources :staging_projects, only: %i[create destroy show], controller: 'webui/staging/projects',
                                 param: :project_name, constraints: cons, as: 'staging_workflow_staging_project' do
      get :preview_copy, on: :member
      post :copy, on: :member
    end
    resources :excluded_requests, controller: 'webui/staging/excluded_requests' do
      collection do
        get :autocomplete
      end
    end
  end
end

resources :reports, only: %i[create show], controller: 'webui/reports'
resources :decisions, only: [:create], controller: 'webui/decisions' do
  resources :appeals, only: %i[new create], controller: 'webui/appeals'
end
resources :appeals, only: [:show], controller: 'webui/appeals'

controller 'webui/comment_locks' do
  post '/comment_locks' => :create, as: 'comment_lock'
  delete '/comment_locks/:comment_lock_id' => :destroy, as: 'comment_unlock'
end

resources :code_of_conduct, only: [:index], controller: 'webui/code_of_conduct'

resource :labels, controller: 'webui/labels', only: %i[update], constraints: cons

resources :global_feature_toggles, only: [:index], controller: 'webui/global_feature_toggles'
