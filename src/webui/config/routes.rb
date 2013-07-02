OBSWebUI::Application.routes.draw do

  cons = { :project => %r{[^\/]*}, :package => %r{[^\/]*}, :binary => %r{[^\/]*}, 
    :user => %r{[^\/]*}, :login => %r{[^\/]*}, :title => %r{[^\/]*}, :service => %r{\w[^\/]*},
    :repository => %r{[^\/]*}, :filename => %r{[^\/]*}, :arch => %r{[^\/]*}, :id => %r{\d*} }

  controller :main do 
    get '/' => :index
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
    get 'package/show/:project/:package' => :show, as: 'package_show', constraints: cons
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
    get 'package/submit_request/:project/:package' => :submit_request, constraints: cons
    get 'package/add_person/:project/:package' => :add_person, constraints: cons
    get 'package/add_group/:project/:package' => :add_group, constraints: cons
    get 'package/rdiff/:project/:package' => :rdiff, constraints: cons
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
    get 'package/view_file/:project/:package' => :view_file, constraints: cons
    post 'package/save_modified_file/:project/:package' => :save_modified_file, constraints: cons
    get 'package/rawsourcefile/:project/:package/:filename' => :rawsourcefile, constraints: cons, as: 'package_rawsourcefile'
    get 'package/rawlog/:project/:package/:repository/:arch' => :rawlog, constraints: cons
    get 'package/live_build_log/:project/:package/:repository/:arch' => :live_build_log, constraints: cons
    get 'package/update_build_log/:project/:package' => :update_build_log, constraints: cons
    get 'package/abort_build/:project/:package' => :abort_build, constraints: cons
    delete 'package/trigger_rebuild/:project/:package' => :trigger_rebuild, constraints: cons
    delete 'package/wipe_binaries/:project/:package' => :wipe_binaries, constraints: cons
    get 'package/devel_project/:project/:package' => :devel_project, constraints: cons
    get 'package/buildresult' => :buildresult, constraints: cons
    get 'package/rpmlint_result' => :rpmlint_result, constraints: cons
    get 'package/rpmlint_log' => :rpmlint_log, constraints: cons
    get 'package/meta/:project/:package' => :meta, constraints: cons
    post 'package/save_meta/:project/:package' => :save_meta, constraints: cons
    get 'package/attributes/:project/:package' => :attributes, constraints: cons, as: 'package_attributes'
    get 'package/edit/:project/:package' => :edit, constraints: cons
    get 'package/repositories/:project/:package' => :repositories, constraints: cons
    post 'package/change_flag/:project/:package' => :change_flag, constraints: cons
    get 'package/import_spec/:project/:package' => :import_spec, constraints: cons
    get "package/files/:project/:package" => :files, constraints: cons
  end

  controller :patchinfo do
    get 'patchinfo/new_patchinfo' => :new_patchinfo
    get 'patchinfo/updatepatchinfo' => :updatepatchinfo
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
    get 'project/users' => :users
    get 'project/subprojects' => :subprojects
    get 'project/attributes' => :attributes
    get 'project/new' => :new
    get 'project/new_incident' => :new_incident
    get 'project/new_package' => :new_package
    get 'project/new_package_branch' => :new_package_branch
    get 'project/incident_request_dialog' => :incident_request_dialog
    post 'project/new_incident_request' => :new_incident_request
    get 'project/release_request_dialog' => :release_request_dialog
    get 'project/new_release_request' => :new_release_request
    get 'project/show' => :show
    get 'project/load_releasetargets' => :load_releasetargets
    get 'project/linking_projects' => :linking_projects
    get 'project/add_repository_from_default_list' => :add_repository_from_default_list
    get 'project/add_repository' => :add_repository
    get 'project/add_person' => :add_person
    get 'project/add_group' => :add_group
    get 'project/buildresult' => :buildresult
    get 'project/delete_dialog' => :delete_dialog
    post 'project/delete' => :delete
    get 'project/edit_repository' => :edit_repository
    post 'project/update_target' => :update_target
    get 'project/repositories' => :repositories
    get 'project/repository_state' => :repository_state
    get 'project/rebuild_time' => :rebuild_time
    get 'project/rebuild_time_png' => :rebuild_time_png
    get 'project/packages' => :packages
    get 'project/requests' => :requests
    post 'project/save_new' => :save_new
    post 'project/save' => :save
    post 'project/save_targets' => :save_targets
    get 'project/remove_target_request_dialog' => :remove_target_request_dialog
    post 'project/remove_target_request' => :remove_target_request
    post 'project/remove_target' => :remove_target
    get 'project/remove_path_from_target' => :remove_path_from_target
    get 'project/move_path_up' => :move_path_up
    get 'project/move_path_down' => :move_path_down
    post 'project/save_person' => :save_person
    post 'project/save_group' => :save_group
    post 'project/remove_role' => :remove_role
    post 'project/remove_person' => :remove_person
    post 'project/remove_group' => :remove_group
    get 'project/monitor' => :monitor
    get 'project/filter_getes?' => :filter_getes?
    get 'project/package_buildresult' => :package_buildresult
    get 'project/toggle_watch' => :toggle_watch
    get 'project/meta' => :meta
    post 'project/save_meta' => :save_meta
    get 'project/prjconf' => :prjconf
    post 'project/save_prjconf' => :save_prjconf
    post 'project/change_flag' => :change_flag
    get 'project/clear_failed_comment' => :clear_failed_comment
    get 'project/edit' => :edit
    get 'project/edit_comment_form' => :edit_comment_form
    post 'project/edit_comment' => :edit_comment
    get 'project/status' => :status
    get 'project/maintained_projects' => :maintained_projects
    get 'project/add_maintained_project_dialog' => :add_maintained_project_dialog
    post 'project/add_maintained_project' => :add_maintained_project
    get 'project/remove_maintained_project' => :remove_maintained_project
    get 'project/maintenance_incidents' => :maintenance_incidents
    get 'project/list_incidents' => :list_incidents
    get 'project/unlock_dialog' => :unlock_dialog
    post 'project/unlock' => :unlock
  end

  controller :request do
    get 'request/add_reviewer_dialog' => :add_reviewer_dialog
    post 'request/add_reviewer' => :add_reviewer
    post 'request/modify_review' => :modify_review
    get 'request/show/:id' => :show
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
    get 'request/set_incident' => :set_incident
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
  get 'apidocs/:filename' => 'apidocs#file', constraints: { :filename => %r{[^\/]*} }

  # Default route geter:
  #get ':controller(/:action(/:id))(.:format)'
end
