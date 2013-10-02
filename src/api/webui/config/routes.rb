Webui::Engine.routes.draw do

  cons = { :project => %r{[^\/]*}, :package => %r{[^\/]*}, :binary => %r{[^\/]*}, 
    :user => %r{[^\/]*}, :login => %r{[^\/]*}, :title => %r{[^\/]*}, :service => %r{\w[^\/]*},
    :repository => %r{[^\/]*}, :filename => %r{[^\/]*}, :arch => %r{[^\/]*}, :id => %r{\d*} }

  root 'main#index'
  controller :main do 
    get 'main/systemstatus' => :systemstatus
    get 'main/news' => :news
    get 'main/latest_updates' => :latest_updates
    get 'main/sitemap' => :sitemap
    get 'main/sitemap_projects' => :sitemap_projects
    get 'main/sitemap_projects_packages' => :sitemap_projects_packages
    get 'main/sitemap_projects_prjconf' => :sitemap_projects_prjconf
    get 'main/sitemap_packages/:listaction' => :sitemap_packages
    get 'main/add_news_dialog' => :add_news_dialog
    post 'main/add_news' => :add_news
    get 'main/delete_message_dialog' => :delete_message_dialog
    post 'main/delete_message' => :delete_message
  end

  controller :attribute do
    get 'attribute/edit' => :edit
    post 'attribute/save' => :save
    match 'attribute/delete' => :delete, via: [:post, :delete]
  end

  controller :configuration do
    get 'configuration/' => :index
    get 'configuration/users' => :users
    get 'configuration/groups' => :groups
    get 'configuration/connect_instance' => :connect_instance
    post 'configuration/save_instance' => :save_instance
    post 'configuration/update_configuration' => :update_configuration
    post 'configuration/update_architectures' => :update_architectures
  end

  controller :driver_update do
    get 'driver_update/create' => :create
    get 'driver_update/edit' => :edit
    post 'driver_update/save' => :save
    get 'driver_update/binaries' => :binaries
  end

  controller :monitor do
    get 'monitor/' => :index
    get 'monitor/old' => :old
    get 'monitor/update_building' => :update_building
    get 'monitor/events' => :events
  end

  controller :package do
    get 'package/show/(:project/(:package))' => :show, as: 'package_show', constraints: cons
    get 'package/linking_packages/:project/:package' => :linking_packages, constraints: cons
    get 'package/dependency/:project/:package' => :dependency, constraints: cons
    get 'package/binary/:project/:package' => :binary, constraints: cons, as: 'package_binary'
    get 'package/binaries/:project/:package' => :binaries, constraints: cons, as: 'package_binaries'
    get 'package/users/:project/:package' => :users, as: 'package_users', constraints: cons
    get 'package/requests/:project/:package' => :requests, as: 'package_requests', constraints: cons
    get 'package/statistics/:project/:package' => :statistics, as: 'package_statistics', constraints: cons
    get 'package/commit/:project/:package' => :commit, as: 'package_commit', constraints: cons
    get 'package/revisions/:project/:package' => :revisions, constraints: cons
    get 'package/submit_request_dialog/:project/:package' => :submit_request_dialog, constraints: cons
    post 'package/submit_request/:project/:package' => :submit_request, constraints: cons
    get 'package/add_person/:project/:package' => :add_person, constraints: cons
    get 'package/add_group/:project/:package' => :add_group, constraints: cons
    get 'package/rdiff/(:project/(:package))' => :rdiff, constraints: cons
    get 'package/wizard_new/:project' => :wizard_new, constraints: cons
    get 'package/wizard/:project/:package' => :wizard, constraints: cons
    post 'package/save_new/:project' => :save_new, constraints: cons
    get 'package/branch_dialog/:project/:package' => :branch_dialog, constraints: cons
    post 'package/branch/:project/:package' => :branch, constraints: cons
    post 'package/save_new_link/:project' => :save_new_link, constraints: cons
    post 'package/save/:project/:package' => :save, constraints: cons
    get 'package/delete_dialog/:project/:package' => :delete_dialog, constraints: cons
    post 'package/remove/:project/:package' => :remove, constraints: cons
    get 'package/add_file/:project/:package' => :add_file, constraints: cons
    post 'package/save_file/:project/:package' => :save_file, constraints: cons
    post 'package/remove_file/:project/:package' => :remove_file, constraints: cons
    post 'package/save_person/:project/:package' => :save_person, constraints: cons
    post 'package/save_group/:project/:package' => :save_group, constraints: cons
    post 'package/remove_role/:project/:package' => :remove_role, constraints: cons
    get 'package/view_file/(:project/(:package/(:filename)))' => :view_file, constraints: cons
    post 'package/save_modified_file/:project/:package' => :save_modified_file, constraints: cons
    get 'package/rawsourcefile/:project/:package/:filename' => :rawsourcefile, constraints: cons, as: 'package_rawsourcefile'
    get 'package/rawlog/:project/:package/:repository/:arch' => :rawlog, constraints: cons
    get 'package/live_build_log/(:project/(:package/(:repository/(:arch))))' => :live_build_log, constraints: cons
    get 'package/update_build_log/:project/:package' => :update_build_log, constraints: cons
    get 'package/abort_build/:project/:package' => :abort_build, constraints: cons
    delete 'package/trigger_rebuild/:project/:package' => :trigger_rebuild, constraints: cons
    delete 'package/wipe_binaries/:project/:package' => :wipe_binaries, constraints: cons
    get 'package/devel_project/:project/:package' => :devel_project, constraints: cons
    get 'package/buildresult' => :buildresult, constraints: cons
    get 'package/rpmlint_result' => :rpmlint_result, constraints: cons
    get 'package/rpmlint_log' => :rpmlint_log, constraints: cons
    get 'package/meta/:project/:package' => :meta, constraints: cons, as: 'package_meta'
    post 'package/save_meta/:project/:package' => :save_meta, constraints: cons
    get 'package/attributes/:project/:package' => :attributes, constraints: cons, as: 'package_attributes'
    get 'package/edit/:project/:package' => :edit, constraints: cons
    get 'package/repositories/:project/:package' => :repositories, constraints: cons
    post 'package/change_flag/:project/:package' => :change_flag, constraints: cons
    get 'package/import_spec/:project/:package' => :import_spec, constraints: cons
    get "package/files/:project/:package" => :files, constraints: cons
    post 'package/comments/:project/:package' => :save_comment, constraints: cons
    post 'package/comments/:project/:package/delete' => :delete_comment, constraints: cons
  end

  controller :patchinfo do
    get 'patchinfo/new_patchinfo' => :new_patchinfo
    post 'patchinfo/updatepatchinfo' => :updatepatchinfo
    get 'patchinfo/edit_patchinfo' => :edit_patchinfo
    get 'patchinfo/show' => :show
    get 'patchinfo/read_patchinfo' => :read_patchinfo
    post 'patchinfo/save' => :save
    post 'patchinfo/remove' => :remove
    get 'patchinfo/new_tracker' => :new_tracker
    get 'patchinfo/get_issue_sum' => :get_issue_sum
    get 'patchinfo/delete_dialog' => :delete_dialog
  end

  controller :project do
    get 'project/' => :index
    get 'project/list_public' => :list_public
    get 'project/list_all' => :list_all
    get 'project/list' => :list
    get 'project/autocomplete_projects' => :autocomplete_projects
    get 'project/autocomplete_incidents' => :autocomplete_incidents
    get 'project/autocomplete_packages' => :autocomplete_packages
    get 'project/autocomplete_repositories' => :autocomplete_repositories
    get 'project/users/:project' => :users, constraints: cons, as: 'project_users'
    get 'project/subprojects/:project' => :subprojects, constraints: cons, as: 'project_subprojects'
    get 'project/attributes/:project' => :attributes, constraints: cons, as: 'project_attributes'
    get 'project/new' => :new
    get 'project/new_incident' => :new_incident
    get 'project/new_package/:project' => :new_package, constraints: cons
    get 'project/new_package_branch/:project' => :new_package_branch, constraints: cons
    get 'project/incident_request_dialog' => :incident_request_dialog
    post 'project/new_incident_request' => :new_incident_request
    get 'project/release_request_dialog' => :release_request_dialog
    post 'project/new_release_request/(:project)' => :new_release_request
    get 'project/show/(:project)' => :show, constraints: cons, as: 'project_show'
    get 'project/linking_projects/:project' => :linking_projects, constraints: cons
    get 'project/add_repository_from_default_list/:project' => :add_repository_from_default_list, constraints: cons
    get 'project/add_repository/:project' => :add_repository, constraints: cons
    get 'project/add_person/:project' => :add_person, constraints: cons
    get 'project/add_group/:project' => :add_group, constraints: cons
    get 'project/buildresult' => :buildresult, constraints: cons
    get 'project/delete_dialog' => :delete_dialog
    post 'project/delete' => :delete
    get 'project/edit_repository/:project' => :edit_repository
    post 'project/update_target/:project' => :update_target
    get 'project/repositories/:project' => :repositories, constraints: cons, as: 'project_repositories'
    get 'project/repository_state/:project' => :repository_state, constraints: cons
    get 'project/rebuild_time/:project' => :rebuild_time, constraints: cons
    get 'project/rebuild_time_png/:project' => :rebuild_time_png, constraints: cons
    get 'project/packages/:project' => :packages, constraints: cons
    get 'project/requests/:project' => :requests, constraints: cons
    post 'project/save_new' => :save_new, constraints: cons
    post 'project/save' => :save, constraints: cons
    post 'project/save_targets' => :save_targets
    get 'project/remove_target_request_dialog' => :remove_target_request_dialog
    post 'project/remove_target_request' => :remove_target_request
    post 'project/remove_target' => :remove_target
    post 'project/remove_path_from_target' => :remove_path_from_target
    post 'project/release_repository/:project/:repository' => :release_repository, constraints: cons
    get 'project/release_repository_dialog/:project/:repository' => :release_repository_dialog, constraints: cons
    get 'project/move_path_up' => :move_path_up
    get 'project/move_path_down' => :move_path_down
    post 'project/save_person/:project' => :save_person, constraints: cons
    post 'project/save_group/:project' => :save_group, constraints: cons
    post 'project/remove_role/:project' => :remove_role, constraints: cons
    post 'project/remove_person/:project' => :remove_person, constraints: cons
    post 'project/remove_group/:project' => :remove_group, constraints: cons
    get 'project/monitor/(:project)' => :monitor, constraints: cons
    get 'project/package_buildresult/:project' => :package_buildresult, constraints: cons
    get 'project/toggle_watch/:project' => :toggle_watch, constraints: cons
    get 'project/meta/:project' => :meta, constraints: cons
    post 'project/save_meta/:project' => :save_meta, constraints: cons
    get 'project/prjconf/:project' => :prjconf, constraints: cons
    post 'project/save_prjconf/:project' => :save_prjconf, constraints: cons
    post 'project/change_flag/:project' => :change_flag, constraints: cons
    get 'project/clear_failed_comment/:project' => :clear_failed_comment, constraints: cons
    get 'project/edit/:project' => :edit, constraints: cons
    get 'project/edit_comment_form/:project' => :edit_comment_form, constraints: cons
    post 'project/edit_comment/:project' => :edit_comment, constraints: cons
    get 'project/status/(:project)' => :status, constraints: cons, as: 'project_status'
    get 'project/maintained_projects/:project' => :maintained_projects, constraints: cons
    get 'project/add_maintained_project_dialog' => :add_maintained_project_dialog, constraints: cons
    post 'project/add_maintained_project' => :add_maintained_project, constraints: cons
    get 'project/remove_maintained_project/:project' => :remove_maintained_project, constraints: cons
    get 'project/maintenance_incidents/:project' => :maintenance_incidents, constraints: cons
    get 'project/list_incidents/:project' => :list_incidents, constraints: cons
    get 'project/unlock_dialog' => :unlock_dialog
    post 'project/unlock' => :unlock
    post 'project/comments/:project' => :save_comment, constraints: cons, as: 'save_project_comment'
    post 'project/comments/:project/delete' => :delete_comment, constraints: cons, as: 'delete_project_comment'
  end

  controller :request do
    get 'request/add_reviewer_dialog' => :add_reviewer_dialog
    post 'request/add_reviewer' => :add_reviewer
    post 'request/modify_review' => :modify_review
    get 'request/show/:id' => :show, as: 'request_show'
    post 'request/sourcediff' => :sourcediff
    post 'request/changerequest' => :changerequest
    get 'request/diff/:id' => :diff
    get 'request/list' => :list
    get 'request/list_small' => :list_small
    get 'request/delete_request_dialog' => :delete_request_dialog
    post 'request/delete_request' => :delete_request
    get 'request/add_role_request_dialog' => :add_role_request_dialog
    post 'request/add_role_request' => :add_role_request
    get 'request/set_bugowner_request_dialog' => :set_bugowner_request_dialog
    post 'request/set_bugowner_request' => :set_bugowner_request
    get 'request/change_devel_request_dialog' => :change_devel_request_dialog
    get 'request/change_devel_request' => :change_devel_request
    get 'request/set_incident_dialog' => :set_incident_dialog
    post 'request/set_incident' => :set_incident
    post 'request/comments/:id' => :save_comment
    post 'request/comments/:id/delete' => :delete_comment, constraints: cons
end

  controller :search do
    match 'search' => :index, via: [:get, :post]
    get 'search/owner' => :owner
  end

  controller :user do
  
    post 'user/register' => :register
    get 'user/register_user' => :register_user

    get 'user/login' => :login
    post 'user/logout' => :logout
    get 'user/logout' => :logout

    post 'user/save' => :save
    get 'user/save_dialog' => :save_dialog

    post 'user/change_password' => :change_password
    get 'user/password_dialog' => :password_dialog

    post 'user/confirm' => :confirm
    post 'user/lock' => :lock
    post 'user/admin' => :admin
    delete 'user/delete' => :delete

    get 'user/autocomplete' => :autocomplete
    get 'user/tokens' => :tokens
  
    post 'user/do_login' => :do_login
    get 'configuration/users/:user' => :edit

  end

  controller :group do
    get 'group/show'  => :show
    get 'group/add'  => :add
    post 'group/save' => :save
    get 'group/autocomplete' => :autocomplete
    get 'group/tokens' => :tokens
    get 'group/edit' => :edit
  end
      
  controller :home do
    # Only here to make old url's work
    get 'home/' => :index 
    get 'home/my_work' => :index
    get 'home/list_my' => :index
    get 'home/requests' => :requests
    get 'home/home_project' => :home_project
    get 'home/remove_watched_project' => :remove_watched_project
    get 'user/:user/icon' => :icon, constraints: cons
  end

  ### /apidocs
  get 'apidocs' => 'apidocs#root'
  get 'apidocs/index' => 'apidocs#index'
  get 'apidocs/:filename' => 'apidocs#file', constraints: { :filename => %r{[^\/]*} }, as: 'apidocs_file'

end
