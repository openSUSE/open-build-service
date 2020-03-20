OBSApi::Application.routes.draw do
  cons = RoutesConstraints::CONS

  constraints(WebuiMatcher) do
    root 'webui/main#index'

    resources :status_messages, only: [:create, :destroy], controller: 'webui/status_messages'

    controller 'webui/feeds' do
      get 'main/news' => :news, constraints: ->(req) { req.format == :rss }, as: :news_feed
      get 'main/latest_updates' => :latest_updates, constraints: ->(req) { req.format == :rss }, as: :latest_updates_feed
      get 'project/latest_commits/:project' => :commits, defaults: { format: 'atom' }, constraints: cons, as: 'commits_feed'
      get 'user/feed/:token' => :notifications, defaults: { format: 'rss' }, as: :user_rss_notifications
    end

    resources :attribs, constraints: cons, only: [:create, :update, :destroy], controller: 'webui/attribute' do
      collection do
        get ':project(/:package)/new' => :new, constraints: cons, as: 'new'
        get ':project(/:package)/:attribute/edit' => :edit, constraints: cons, as: 'edit'
        get ':project(/:package)' => :index, constraints: cons, as: 'index', defaults: { format: 'html' }
      end
    end

    resources :image_templates, constraints: cons, only: [:index], controller: 'webui/image_templates'

    resources :download_repositories, constraints: cons, only: [:create, :update, :destroy], controller: 'webui/download_on_demand'

    controller 'webui/configuration' do
      get 'configuration' => :index
      patch 'configuration' => :update
    end
    resources :interconnects, only: [:new, :create], controller: 'webui/interconnects'

    controller 'webui/subscriptions' do
      get 'notifications' => :index
      put 'notifications' => :update
    end

    controller 'webui/architectures' do
      patch 'architectures/bulk_update_availability' => :bulk_update_availability, as: :bulk_update_availability
    end

    resources :architectures, only: [:index, :update], controller: 'webui/architectures'

    controller 'webui/monitor' do
      get 'monitor/' => :index
      get 'monitor/old' => :old
      get 'monitor/update_building' => :update_building
      get 'monitor/events' => :events, as: :monitor_events
    end

    resources :package, only: [:index], controller: 'webui/package', constraints: cons

    defaults format: 'html' do
      controller 'webui/package' do
        get 'package/show/:project/:package' => :show, as: 'package_show', constraints: cons
        get 'package/branch_diff_info/:project/:package' => :branch_diff_info, as: 'package_branch_diff_info', constraints: cons
        get 'package/dependency/:project/:package' => :dependency, constraints: cons, as: 'package_dependency'
        get 'package/binary/:project/:package/:repository/:arch/:filename' => :binary, constraints: cons, as: 'package_binary'
        get 'package/binary/download/:project/:package/:repository/:arch/:filename' => :binary_download,
            constraints: cons, as: 'package_binary_download'
        get 'package/binaries/:project/:package/:repository' => :binaries, constraints: cons, as: 'package_binaries'
        get 'package/users/:project/:package' => :users, as: 'package_users', constraints: cons
        get 'package/requests/:project/:package' => :requests, as: 'package_requests', constraints: cons
        get 'package/statistics/:project/:package/:repository/:arch' => :statistics, as: 'package_statistics', constraints: cons
        get 'package/revisions/:project/:package' => :revisions, constraints: cons, as: 'package_view_revisions'
        post 'package/submit_request/:project/:package' => :submit_request, constraints: cons
        get 'package/rdiff/:project/:package' => :rdiff, constraints: cons, as: 'package_rdiff'
        post 'package/save_new/:project' => :save_new, constraints: cons, as: 'save_new_package'
        post 'package/branch' => :branch, constraints: cons
        post 'package/save/:project/:package' => :save, constraints: cons, as: 'package_save'
        post 'package/remove/:project/:package' => :remove, constraints: cons
        get 'package/add_file/:project/:package' => :add_file, constraints: cons, as: 'package_add_file'
        post 'package/save_file/:project/:package' => :save_file, constraints: cons
        post 'package/remove_file/:project/:package/:filename' => :remove_file, constraints: cons
        post 'package/save_person/:project/:package' => :save_person, constraints: cons, as: 'package_save_person'
        post 'package/save_group/:project/:package' => :save_group, constraints: cons, as: 'package_save_group'
        post 'package/remove_role/:project/:package' => :remove_role, constraints: cons, as: 'package_remove_role'
        get 'package/view_file/:project/:package/(:filename)' => :view_file, constraints: cons, as: 'package_view_file'
        get 'package/live_build_log/:project/:package/:repository/:arch' => :live_build_log, constraints: cons, as: 'package_live_build_log'
        defaults format: 'js' do
          get 'package/update_build_log/:project/:package/:repository/:arch' => :update_build_log, constraints: cons, as: 'package_update_build_log'
          post 'package/trigger_rebuild/:project/:package' => :trigger_rebuild, constraints: cons, as: 'package_trigger_rebuild'
          get 'package/abort_build/:project/:package' => :abort_build, constraints: cons, as: 'package_abort_build'
          post 'package/trigger_services/:project/:package' => :trigger_services, constraints: cons, as: 'package_trigger_services'
          delete 'package/wipe_binaries/:project/:package' => :wipe_binaries, constraints: cons, as: 'package_wipe_binaries'
        end
        get 'package/devel_project/:project/:package' => :devel_project, constraints: cons, as: 'package_devel_project'
        get 'package/buildresult' => :buildresult, constraints: cons, as: 'package_buildresult'
        get 'package/rpmlint_result' => :rpmlint_result, constraints: cons, as: 'rpmlint_result'
        get 'package/rpmlint_log' => :rpmlint_log, constraints: cons
        get 'package/meta/:project/:package' => :meta, constraints: cons, as: 'package_meta'
        post 'package/save_meta/:project/:package' => :save_meta, constraints: cons, as: 'package_save_meta'
        # For backward compatibility
        get 'package/attributes/:project/:package', to: redirect('/attribs/%{project}/%{package}'), constraints: cons
        # For backward compatibility
        get 'package/repositories/:project/:package', to: redirect('/repositories/%{project}/%{package}'), constraints: cons
        # For backward compatibility
        get 'package/files/:project/:package' => :show, constraints: cons
      end
    end

    resources :packages, only: [], param: :name do
      resource :job_history, controller: 'webui/packages/job_history', only: [] do
        get '/:project/:repository/:arch' => :index, as: :index, constraints: cons
      end

      resource :build_reason, controller: 'webui/packages/build_reason', only: [] do
        get '/:project/:repository/:arch' => :index, as: :index, constraints: cons
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
      get 'project/add_repository/:project' => :new, constraints: cons
      get 'project/add_repository_from_default_list/:project' => :distributions, constraints: cons, as: :repositories_distributions
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

    resources :kiwi_images, only: [:show, :edit, :update], controller: 'webui/kiwi/images' do
      member do
        get 'build_result' => :build_result, constraints: cons
        get 'autocomplete_binaries' => :autocomplete_binaries, as: :autocomplete_binaries
      end
    end

    scope :cloud, as: :cloud do
      resources :configuration, only: [:index], controller: 'webui/cloud/configurations'

      resources :upload, only: [:index, :create, :destroy], controller: 'webui/cloud/upload_jobs' do
        new do
          get ':project/:package/:repository/:arch/:filename', to: 'webui/cloud/upload_jobs#new', as: '', constraints: cons
        end

        resource :log, only: :show, controller: 'webui/cloud/upload_job/logs'
      end
      scope :azure, as: :azure do
        resource :configuration, only: [:show, :update, :destroy], controller: 'webui/cloud/azure/configurations'
        resource :upload, only: [:create], controller: 'webui/cloud/azure/upload_jobs' do
          new do
            get ':project/:package/:repository/:arch/:filename', to: 'webui/cloud/azure/upload_jobs#new', as: '', constraints: cons
          end
        end
      end
      scope :ec2, as: :ec2 do
        resource :configuration, only: [:show, :update], controller: 'webui/cloud/ec2/configurations'
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
      get 'project/autocomplete_incidents' => :autocomplete_incidents, as: 'autocomplete_incidents'
      get 'project/autocomplete_packages' => :autocomplete_packages, as: 'autocomplete_packages'
      get 'project/autocomplete_repositories' => :autocomplete_repositories, as: 'autocomplete_repositories'
      get 'project/users/:project' => :users, constraints: cons, as: 'project_users'
      get 'project/subprojects/:project' => :subprojects, constraints: cons, as: 'project_subprojects'
      get 'project/attributes/:project', to: redirect('/attribs/%{project}'), constraints: cons
      get 'project/new_package/:project' => :new_package, constraints: cons, as: 'project_new_package'
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
      # TODO: this should be POST (and the link AJAX)
      get 'project/toggle_watch/:project' => :toggle_watch, constraints: cons, as: 'project_toggle_watch'
      get 'project/clear_failed_comment/:project' => :clear_failed_comment, constraints: cons, as: :clear_failed_comment
      get 'project/edit_comment_form/:project' => :edit_comment_form, constraints: cons, as: :edit_comment_form
      post 'project/edit_comment/:project' => :edit_comment, constraints: cons
      post 'project/unlock' => :unlock
      get 'project/keys_and_certificates/:project' => :keys_and_certificates, constraints: cons, as: 'keys_and_certificates'
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
    # \For backward compatibility

    resources :projects, only: [], param: :name do
      resources :maintained_projects, controller: 'webui/projects/maintained_projects',
                                      param: :maintained_project, only: [:index, :destroy, :create], constraints: cons
      resource :status, controller: 'webui/projects/status', only: [:show], constraints: cons
      resource :public_key, controller: 'webui/projects/public_key', only: [:show], constraints: cons
      resource :ssl_certificate, controller: 'webui/projects/ssl_certificate', only: [:show], constraints: cons
      resource :pulse, controller: 'webui/projects/pulse', only: [:show], constraints: cons
      resource :meta, controller: 'webui/projects/meta', only: [:show, :update], constraints: cons
      resource :prjconf, controller: 'webui/projects/project_configuration', only: [:show, :update], as: :config, constraints: cons
      resource :rebuild_time, controller: 'webui/projects/rebuild_times', only: [:show], constraints: cons do
        get 'rebuild_time_png'
      end
      resources :maintenance_incidents, controller: 'webui/projects/maintenance_incidents', only: [:index, :create], constraints: cons do
        collection do
          post 'create_request'
        end
      end
    end

    controller 'webui/request' do
      post 'request/add_reviewer' => :add_reviewer
      post 'request/modify_review' => :modify_review
      get 'request/show/:number' => :show, as: 'request_show', constraints: cons
      post 'request/sourcediff' => :sourcediff
      post 'request/changerequest' => :changerequest
      get 'request/diff/:number' => :diff
      get 'request/list_small' => :list_small, as: 'request_list_small'
      post 'request/delete_request/:project' => :delete_request, constraints: cons, as: 'delete_request'
      post 'request/add_role_request/:project' => :add_role_request, constraints: cons, as: 'add_role_request'
      post 'request/set_bugowner_request' => :set_bugowner_request
      post 'request/change_devel_request/:project/:package' => :change_devel_request, constraints: cons, as: 'change_devel_request'
    end

    controller 'webui/search' do
      match 'search' => :index, via: [:get, :post]
      get 'search/owner' => :owner
      get 'search/issue' => :issue
    end

    resources :users, controller: 'webui/users', param: :login, constraints: cons do
      resources :requests, only: [:index], controller: 'webui/users/bs_requests'
      resources :notifications, only: [:index, :update], controller: 'webui/users/notifications'
      collection do
        get 'autocomplete'
        get 'tokens'
      end
      member do
        post 'change_password'
      end
    end

    scope :my do
      resources :tasks, only: [:index], controller: 'webui/users/tasks', as: :my_tasks
      get 'notifications' => :index,  controller: 'webui/users/subscriptions', as: :my_notifications
      put 'notifications' => :update, controller: 'webui/users/subscriptions'
      post 'rss_tokens' => :create, controller: 'webui/users/rss_tokens', as: :my_rss_token
      # To accept announcements as user
      post 'announcements/:id' => :create, controller: 'webui/users/announcements', as: :my_announcements
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
      get '/show/:user', to: redirect('/users/%{user}')
      get '/autocomplete', to: redirect('/users/autocomplete')
      get '/tokens', to: redirect('/users/tokens')
    end
    # Legacy routes end

    resources :announcements, only: :show, controller: 'webui/announcements'

    resource :session, only: [:new, :create, :destroy], controller: 'webui/session'

    controller 'webui/groups/bs_requests' do
      get 'groups/(:title)/requests' => :index, constraints: { title: /[^\/]*/ }, as: 'group_requests'
    end

    controller 'webui/groups' do
      get 'groups' => :index
      get 'group/show/:title' => :show, constraints: { title: /[^\/]*/ }, as: 'group_show'
      get 'group/new' => :new
      post 'group/create' => :create
      get 'group/autocomplete' => :autocomplete, as: 'autocomplete_groups'
    end

    resources :groups, only: [], param: :title, constraints: { title: /[^\/]*/ } do
      resources :user, only: [:create, :destroy, :update], constraints: cons, param: :user_login, controller: 'webui/groups/users'
    end

    resources :comments, constraints: cons, only: [:create, :destroy], controller: 'webui/comments'

    ### /apidocs
    get 'apidocs', to: redirect('/apidocs/index')
    get 'apidocs/(index)' => 'webui/apidocs#index', as: 'apidocs_index'
  end

  resources :staging_workflows, except: :index, controller: 'webui/staging/workflows', param: :workflow_project, constraints: cons do
    member do
      resources :staging_projects, only: [:create, :destroy, :show], controller: 'webui/staging/projects',
                                   param: :project_name, constraints: cons, as: 'staging_workflow_staging_project' do
        get :preview_copy, on: :member
        post :copy, on: :member
      end
      resources :excluded_requests, controller: 'webui/staging/excluded_requests'
    end
  end
end
