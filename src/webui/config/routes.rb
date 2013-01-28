OBSWebUI::Application.routes.draw do

  cons = { :project => %r{[^\/]*}, :package => %r{[^\/]*}, :binary => %r{[^\/]*}, 
    :user => %r{[^\/]*}, :login => %r{[^\/]*}, :title => %r{[^\/]*}, :service => %r{\w[^\/]*},
    :repository => %r{[^\/]*}, :filename => %r{[^\/]*}, :arch => %r{[^\/]*}, :id => %r{\d*} }

  controller :main do 
    match '/' => :index
    match 'main/systemstatus' => :systemstatus
    match 'main/news' => :news
    match 'main/latest_updates' => :latest_updates
    match 'main/sitemap' => :sitemap
    match 'main/sitemap_projects' => :sitemap_projects
    match 'main/sitemap_projects_packages' => :sitemap_projects_packages
    match 'main/sitemap_projects_prjconf' => :sitemap_projects_prjconf
    match 'main/sitemap_packages/:listaction' => :sitemap_packages
    match 'main/add_news_dialog' => :add_news_dialog
    match 'main/add_news' => :add_news
    match 'main/delete_message_dialog' => :delete_message_dialog
    match 'main/delete_message' => :delete_message, via: :post
  end

  controller :attribute do
    match 'attribute/edit' => :edit
    match 'attribute/save' => :save, via: :post
    match 'attribute/delete' => :delete, via: [:post, :delete]
  end

  controller :configuration do
    match 'configuration/' => :index
    match 'configuration/users' => :users
    match 'configuration/groups' => :groups
    match 'configuration/connect_instance' => :connect_instance
    match 'configuration/save_instance' => :save_instance
    match 'configuration/update_configuration' => :update_configuration, via: :post
    match 'configuration/update_architectures' => :update_architectures, via: :post
  end

  controller :driver_update do
    match 'driver_update/create' => :create
    match 'driver_update/edit' => :edit
    match 'driver_update/save' => :save, via: :post
    match 'driver_update/binaries' => :binaries
  end

  resources :groups, :controller => 'group', :only => [:index, :show] do
    collection do
      get 'autocomplete'
    end
  end

  controller :home do
    match 'home/' => :index
    match 'home/:user/icon' => :icon, constraints: cons
    match 'home/my_work' => :my_work
    match 'home/requests' => :requests
    match 'home/home_project' => :home_project
    match 'home/list_my' => :list_my
    match 'home/remove_watched_project' => :remove_watched_project
  end

  controller :monitor do
    match 'monitor/' => :index
    match 'monitor/old' => :old
    match 'monitor/update_building' => :update_building
    match 'monitor/events' => :events
  end

  controller :package do
    match 'package/show' => :show
    match 'package/linking_packages' => :linking_packages
    match 'package/dependency' => :dependency
    match 'package/binary' => :binary
    match 'package/binaries' => :binaries
    match 'package/users' => :users
    match 'package/requests' => :requests
    match 'package/statistics' => :statistics
    match 'package/commit' => :commit
    match 'package/revisions' => :revisions
    match 'package/submit_request_dialog' => :submit_request_dialog
    match 'package/submit_request' => :submit_request
    match 'package/add_person' => :add_person
    match 'package/add_group' => :add_group
    match 'package/rdiff' => :rdiff
    match 'package/wizard_new' => :wizard_new
    match 'package/wizard' => :wizard
    match 'package/save_new' => :save_new, via: :post
    match 'package/branch_dialog' => :branch_dialog
    match 'package/branch' => :branch, via: :post
    match 'package/save_new_link' => :save_new_link, via: :post
    match 'package/save' => :save, via: :post
    match 'package/delete_dialog' => :delete_dialog
    match 'package/remove' => :remove, via: :post
    match 'package/add_file' => :add_file
    match 'package/save_file' => :save_file, via: :post
    match 'package/remove_file' => :remove_file, via: :post
    match 'package/save_person' => :save_person, via: :post
    match 'package/save_group' => :save_group, via: :post
    match 'package/remove_role' => :remove_role, via: :post
    match 'package/view_file' => :view_file
    match 'package/save_modified_file' => :save_modified_file, via: :post
    match 'package/rawsourcefile' => :rawsourcefile, via: :get
    match 'package/rawlog' => :rawlog, via: :get
    match 'package/live_build_log' => :live_build_log
    match 'package/update_build_log' => :update_build_log
    match 'package/abort_build' => :abort_build
    match 'package/trigger_rebuild' => :trigger_rebuild, via: :delete
    match 'package/wipe_binaries' => :wipe_binaries, via: :delete
    match 'package/devel_project' => :devel_project
    match 'package/buildresult' => :buildresult
    match 'package/rpmlint_result' => :rpmlint_result
    match 'package/rpmlint_log' => :rpmlint_log
    match 'package/meta' => :meta
    match 'package/save_meta' => :save_meta, via: :post
    match 'package/attributes' => :attributes
    match 'package/edit' => :edit
    match 'package/repositories' => :repositories
    match 'package/change_flag' => :change_flag, via: :post
    match 'package/import_spec' => :import_spec
    match "package/files" => :files
  end

  controller :patchinfo do
    match 'patchinfo/new_patchinfo' => :new_patchinfo
    match 'patchinfo/updatepatchinfo' => :updatepatchinfo
    match 'patchinfo/edit_patchinfo' => :edit_patchinfo
    match 'patchinfo/show' => :show
    match 'patchinfo/read_patchinfo' => :read_patchinfo
    match 'patchinfo/save' => :save, via: :post
    match 'patchinfo/remove' => :remove, via: :post
    match 'patchinfo/new_tracker' => :new_tracker
    match 'patchinfo/get_issue_sum' => :get_issue_sum
    match 'patchinfo/delete_dialog' => :delete_dialog
  end

  controller :project do
    match 'project/' => :index
    match 'project/list_public' => :list_public
    match 'project/list_all' => :list_all
    match 'project/list' => :list
    match 'project/autocomplete_projects' => :autocomplete_projects
    match 'project/autocomplete_incidents' => :autocomplete_incidents
    match 'project/autocomplete_packages' => :autocomplete_packages
    match 'project/autocomplete_repositories' => :autocomplete_repositories
    match 'project/users' => :users
    match 'project/subprojects' => :subprojects
    match 'project/attributes' => :attributes
    match 'project/new' => :new
    match 'project/new_incident' => :new_incident
    match 'project/new_package' => :new_package
    match 'project/new_package_branch' => :new_package_branch
    match 'project/incident_request_dialog' => :incident_request_dialog
    match 'project/new_incident_request' => :new_incident_request
    match 'project/release_request_dialog' => :release_request_dialog
    match 'project/new_release_request' => :new_release_request
    match 'project/show' => :show
    match 'project/load_releasetargets' => :load_releasetargets
    match 'project/linking_projects' => :linking_projects
    match 'project/add_repository_from_default_list' => :add_repository_from_default_list
    match 'project/add_repository' => :add_repository
    match 'project/add_person' => :add_person
    match 'project/add_group' => :add_group
    match 'project/buildresult' => :buildresult
    match 'project/delete_dialog' => :delete_dialog
    match 'project/delete' => :delete, via: :post
    match 'project/edit_repository' => :edit_repository
    match 'project/update_target' => :update_target, via: :post
    match 'project/repositories' => :repositories
    match 'project/repository_state' => :repository_state
    match 'project/rebuild_time' => :rebuild_time
    match 'project/rebuild_time_png' => :rebuild_time_png
    match 'project/packages' => :packages
    match 'project/requests' => :requests
    match 'project/save_new' => :save_new
    match 'project/save' => :save
    match 'project/save_targets' => :save_targets, via: :post
    match 'project/remove_target_request_dialog' => :remove_target_request_dialog
    match 'project/remove_target_request' => :remove_target_request
    match 'project/remove_target' => :remove_target, via: :post
    match 'project/remove_path_from_target' => :remove_path_from_target
    match 'project/move_path_up' => :move_path_up
    match 'project/move_path_down' => :move_path_down
    match 'project/save_person' => :save_person, via: :post
    match 'project/save_group' => :save_group, via: :post
    match 'project/remove_role' => :remove_role, via: :post
    match 'project/remove_person' => :remove_person, via: :post
    match 'project/remove_group' => :remove_group, via: :post
    match 'project/monitor' => :monitor
    match 'project/filter_matches?' => :filter_matches?
    match 'project/package_buildresult' => :package_buildresult
    match 'project/toggle_watch' => :toggle_watch
    match 'project/meta' => :meta
    match 'project/save_meta' => :save_meta, via: :post
    match 'project/prjconf' => :prjconf
    match 'project/save_prjconf' => :save_prjconf, via: :post
    match 'project/change_flag' => :change_flag, via: :post
    match 'project/clear_failed_comment' => :clear_failed_comment
    match 'project/edit' => :edit
    match 'project/edit_comment_form' => :edit_comment_form
    match 'project/edit_comment' => :edit_comment, via: :post
    match 'project/status' => :status
    match 'project/maintained_projects' => :maintained_projects
    match 'project/add_maintained_project_dialog' => :add_maintained_project_dialog
    match 'project/add_maintained_project' => :add_maintained_project
    match 'project/remove_maintained_project' => :remove_maintained_project
    match 'project/maintenance_incidents' => :maintenance_incidents
    match 'project/list_incidents' => :list_incidents
    match 'project/unlock_dialog' => :unlock_dialog
    match 'project/unlock' => :unlock, via: :post
  end

  controller :request do
    match 'request/add_reviewer_dialog' => :add_reviewer_dialog
    match 'request/add_reviewer' => :add_reviewer, via: :post
    match 'request/modify_review' => :modify_review, via: :post
    match 'request/show/:id' => :show
    match 'request/sourcediff' => :sourcediff
    match 'request/changerequest' => :changerequest, via: :post
    match 'request/diff/:id' => :diff
    match 'request/list' => :list
    match 'request/list_small' => :list_small
    match 'request/delete_request_dialog' => :delete_request_dialog
    match 'request/delete_request' => :delete_request, via: :post
    match 'request/add_role_request_dialog' => :add_role_request_dialog
    match 'request/add_role_request' => :add_role_request, via: :post
    match 'request/set_bugowner_request_dialog' => :set_bugowner_request_dialog
    match 'request/set_bugowner_request' => :set_bugowner_request, via: :post
    match 'request/change_devel_request_dialog' => :change_devel_request_dialog
    match 'request/change_devel_request' => :change_devel_request
    match 'request/set_incident_dialog' => :set_incident_dialog
    match 'request/set_incident' => :set_incident
  end

  controller :search do
    match 'search' => :index
    match 'search/owner' => :owner
  end

  controller :user do
    match 'user/do_login' => :do_login
    match 'user/edit' => :edit
    match 'user/register' => :register, via: :post
    match 'user/register_user' => :register_user
    match 'user/login' => :login
    match 'user/logout' => :logout
    match 'user/save' => :save
    match 'user/change_password' => :change_password, via: :post
    match 'user/autocomplete' => :autocomplete
  end

  ### /apidocs
  match 'apidocs' => 'apidocs#root'
  match 'apidocs/index' => 'apidocs#index'
  match 'apidocs/:filename' => 'apidocs#file', constraints: { :filename => %r{[^\/]*} }

  # Default route matcher:
  #match ':controller(/:action(/:id))(.:format)'
end
