require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"
require 'nokogiri'

class AllRoutesTest < ActionDispatch::IntegrationTest

  test "visit all routes" do
    # rake routes | cut -b-40 | sed -e 's,  *,,g' | grep -v '^$' | sed -e 's,^\(.*\),    urls << \1_path,' 
    urls = Array.new
    urls << main_systemstatus_path
    urls << main_news_path
    urls << main_latest_updates_path
    urls << main_sitemap_path
    urls << main_sitemap_projects_path
    urls << main_sitemap_projects_packages_path
    urls << main_sitemap_projects_prjconf_path
    urls << main_add_news_dialog_path
    urls << main_add_news_path
    urls << main_delete_message_dialog_path
    urls << main_delete_message_path
    urls << attribute_edit_path
    urls << attribute_save_path
    urls << attribute_delete_path
    urls << configuration_path
    urls << configuration_users_path
    urls << configuration_groups_path
    urls << configuration_connect_instance_path
    urls << configuration_save_instance_path
    urls << configuration_update_configuration_path
    urls << configuration_update_architectures_path
    urls << driver_update_create_path
    urls << driver_update_edit_path
    urls << driver_update_save_path
    urls << driver_update_binaries_path
    urls << monitor_path
    urls << monitor_old_path
    urls << monitor_update_building_path
    urls << monitor_events_path
    urls << url_for(controller: :package, action: :show, project: 'kde4', package: 'kdelibs4')
    urls << url_for(controller: :package, action: :linking_packages, project: 'kde4', package: 'kdelibs4')
    urls << url_for(controller: :package, action: :dependency, project: 'kde4', package: 'kdelibs4')
    urls << url_for(controller: :package, action: :binary, project: 'kde4', package: 'kdelibs4')
    urls << url_for(controller: :package, action: :binaries, project: 'kde4', package: 'kdelibs4')
    urls << url_for(controller: :package, action: :users, project: 'kde4', package: 'kdelibs4')
    urls << url_for(controller: :package, action: :requests, project: 'kde4', package: 'kdelibs4')
    urls << url_for(controller: :package, action: :statistics, project: 'kde4', package: 'kdelibs4')
    urls << url_for(controller: :package, action: :commit, project: 'kde4', package: 'kdelibs4')
    urls << url_for(controller: :package, action: :revisions, project: 'kde4', package: 'kdelibs4')
    urls << url_for(controller: :package, action: :submit_request_dialog, project: 'kde4', package: 'kdelibs4')
    urls << url_for(controller: :package, action: :submit_request, project: 'kde4', package: 'kdelibs4')
    urls << url_for(controller: :package, action: :add_person, project: 'kde4', package: 'kdelibs4')
    urls << url_for(controller: :package, action: :add_group, project: 'kde4', package: 'kdelibs4')
    urls << url_for(controller: :package, action: :rdiff, project: 'kde4', package: 'kdelibs4')
    urls << url_for(controller: :package, action: :wizard_new, project: 'kde4', package: 'kdelibs4')
    urls << url_for(controller: :package, action: :wizard, project: 'kde4', package: 'kdelibs4')
    urls << url_for(controller: :package, action: :save_new, project: 'kde4', package: 'kdelibs4')
    urls << url_for(controller: :package, action: :branch_dialog, project: 'kde4', package: 'kdelibs4')
    urls << url_for(controller: :package, action: :branch, project: 'kde4', package: 'kdelibs4')
    urls << url_for(controller: :package, action: :save_new_link, project: 'kde4', package: 'kdelibs4')
    urls << url_for(controller: :package, action: :save, project: 'kde4', package: 'kdelibs4')
    urls << url_for(controller: :package, action: :delete_dialog, project: 'kde4', package: 'kdelibs4')
    urls << url_for(controller: :package, action: :remove, project: 'kde4', package: 'kdelibs4')
    urls << url_for(controller: :package, action: :add_file, project: 'kde4', package: 'kdelibs4')
    urls << url_for(controller: :package, action: :save_file, project: 'kde4', package: 'kdelibs4')
    urls << url_for(controller: :package, action: :remove_file, project: 'kde4', package: 'kdelibs4')
    urls << url_for(controller: :package, action: :save_person, project: 'kde4', package: 'kdelibs4')
    urls << url_for(controller: :package, action: :save_group, project: 'kde4', package: 'kdelibs4')
    urls << url_for(controller: :package, action: :remove_role, project: 'kde4', package: 'kdelibs4')
    urls << url_for(controller: :package, action: :view_file, project: 'kde4', package: 'kdelibs4')
    urls << url_for(controller: :package, action: :save_modified_file, project: 'kde4', package: 'kdelibs4')
    urls << url_for(controller: :package, action: :update_build_log, project: 'kde4', package: 'kdelibs4')
    urls << url_for(controller: :package, action: :abort_build, project: 'kde4', package: 'kdelibs4')
    urls << url_for(controller: :package, action: :trigger_rebuild, project: 'kde4', package: 'kdelibs4')
    urls << url_for(controller: :package, action: :wipe_binaries, project: 'kde4', package: 'kdelibs4')
    urls << url_for(controller: :package, action: :devel_project, project: 'kde4', package: 'kdelibs4')
    urls << url_for(controller: :package, action: :buildresult, project: 'kde4', package: 'kdelibs4')
    urls << url_for(controller: :package, action: :rpmlint_result, project: 'kde4', package: 'kdelibs4')
    urls << url_for(controller: :package, action: :rpmlint_log, project: 'kde4', package: 'kdelibs4')
    urls << url_for(controller: :package, action: :meta, project: 'kde4', package: 'kdelibs4')
    urls << url_for(controller: :package, action: :save_meta, project: 'kde4', package: 'kdelibs4')
    urls << url_for(controller: :package, action: :attributes, project: 'kde4', package: 'kdelibs4')
    urls << url_for(controller: :package, action: :edit, project: 'kde4', package: 'kdelibs4')
    urls << url_for(controller: :package, action: :repositories, project: 'kde4', package: 'kdelibs4')
    urls << url_for(controller: :package, action: :change_flag, project: 'kde4', package: 'kdelibs4')
    urls << url_for(controller: :package, action: :import_spec, project: 'kde4', package: 'kdelibs4')
    urls << url_for(controller: :package, action: :files, project: 'kde4', package: 'kdelibs4')
    urls << patchinfo_new_patchinfo_path
    urls << patchinfo_updatepatchinfo_path
    urls << patchinfo_edit_patchinfo_path
    urls << patchinfo_show_path
    urls << patchinfo_read_patchinfo_path
    urls << patchinfo_save_path
    urls << patchinfo_remove_path
    urls << patchinfo_new_tracker_path
    urls << patchinfo_get_issue_sum_path
    urls << patchinfo_delete_dialog_path
    urls << project_path
    urls << project_list_public_path
    urls << project_list_all_path
    urls << project_list_path
    urls << url_for(controller: :project, action: :users, project: 'kde4')
    urls << url_for(controller: :project, action: :subprojects, project: 'kde4')
    urls << url_for(controller: :project, action: :attributes, project: 'kde4')
    urls << url_for(controller: :project, action: :new, project: 'kde4')
    urls << url_for(controller: :project, action: :new_incident, project: 'kde4')
    urls << url_for(controller: :project, action: :new_package, project: 'kde4')
    urls << url_for(controller: :project, action: :new_package_branch, project: 'kde4')
    urls << url_for(controller: :project, action: :incident_request_dialog, project: 'kde4')
    urls << url_for(controller: :project, action: :new_incident_request, project: 'kde4')
    urls << url_for(controller: :project, action: :release_request_dialog, project: 'kde4')
    urls << url_for(controller: :project, action: :new_release_request, project: 'kde4')
    urls << url_for(controller: :project, action: :show, project: 'kde4')
    urls << url_for(controller: :project, action: :linking_projects, project: 'kde4')
    urls << url_for(controller: :project, action: :add_repository_from_default_list, project: 'kde4')
    urls << url_for(controller: :project, action: :add_repository, project: 'kde4')
    urls << url_for(controller: :project, action: :add_person, project: 'kde4')
    urls << url_for(controller: :project, action: :add_group, project: 'kde4')
    urls << url_for(controller: :project, action: :buildresult, project: 'kde4')
    urls << url_for(controller: :project, action: :delete_dialog, project: 'kde4')
    urls << url_for(controller: :project, action: :delete, project: 'kde4')
    urls << url_for(controller: :project, action: :edit_repository, project: 'kde4')
    urls << url_for(controller: :project, action: :update_target, project: 'kde4')
    urls << url_for(controller: :project, action: :repositories, project: 'kde4')
    urls << url_for(controller: :project, action: :repository_state, project: 'kde4')
    urls << url_for(controller: :project, action: :packages, project: 'kde4')
    urls << url_for(controller: :project, action: :requests, project: 'kde4')
    urls << url_for(controller: :project, action: :save_new, project: 'kde4')
    urls << url_for(controller: :project, action: :save, project: 'kde4')
    urls << url_for(controller: :project, action: :save_targets, project: 'kde4')
    urls << url_for(controller: :project, action: :remove_target_request_dialog, project: 'kde4')
    urls << url_for(controller: :project, action: :remove_target_request, project: 'kde4')
    urls << url_for(controller: :project, action: :remove_target, project: 'kde4')
    urls << url_for(controller: :project, action: :move_path_up, project: 'kde4')
    urls << url_for(controller: :project, action: :move_path_down, project: 'kde4')
    urls << url_for(controller: :project, action: :save_person, project: 'kde4')
    urls << url_for(controller: :project, action: :save_group, project: 'kde4')
    urls << url_for(controller: :project, action: :remove_role, project: 'kde4')
    urls << url_for(controller: :project, action: :remove_person, project: 'kde4')
    urls << url_for(controller: :project, action: :remove_group, project: 'kde4')
    urls << url_for(controller: :project, action: :monitor, project: 'kde4')
    urls << url_for(controller: :project, action: :package_buildresult, project: 'kde4')
    urls << url_for(controller: :project, action: :toggle_watch, project: 'kde4')
    urls << url_for(controller: :project, action: :meta, project: 'kde4')
    urls << url_for(controller: :project, action: :save_meta, project: 'kde4')
    urls << url_for(controller: :project, action: :prjconf, project: 'kde4')
    urls << url_for(controller: :project, action: :save_prjconf, project: 'kde4')
    urls << url_for(controller: :project, action: :change_flag, project: 'kde4')
    urls << url_for(controller: :project, action: :clear_failed_comment, project: 'kde4')
    urls << url_for(controller: :project, action: :edit, project: 'kde4')
    urls << url_for(controller: :project, action: :edit_comment_form, project: 'kde4')
    urls << url_for(controller: :project, action: :edit_comment, project: 'kde4')
    urls << url_for(controller: :project, action: :status, project: 'kde4')
    urls << url_for(controller: :project, action: :maintained_projects, project: 'kde4')
    urls << url_for(controller: :project, action: :add_maintained_project_dialog, project: 'kde4')
    urls << url_for(controller: :project, action: :add_maintained_project, project: 'kde4')
    urls << url_for(controller: :project, action: :remove_maintained_project, project: 'kde4')
    urls << url_for(controller: :project, action: :maintenance_incidents, project: 'kde4')
    urls << url_for(controller: :project, action: :list_incidents, project: 'kde4')
    urls << url_for(controller: :project, action: :unlock_dialog, project: 'kde4')
    urls << url_for(controller: :project, action: :unlock, project: 'kde4')
    urls << request_add_reviewer_dialog_path
    urls << request_add_reviewer_path
    urls << request_modify_review_path
    urls << request_sourcediff_path
    urls << request_changerequest_path
    urls << request_list_path
    urls << request_list_small_path
    urls << request_delete_request_dialog_path
    urls << request_delete_request_path
    urls << request_add_role_request_dialog_path
    urls << request_add_role_request_path
    urls << request_set_bugowner_request_dialog_path
    urls << request_set_bugowner_request_path
    urls << request_change_devel_request_dialog_path
    urls << request_change_devel_request_path
    urls << request_set_incident_dialog_path
    urls << request_set_incident_path
    urls << search_path
    urls << search_owner_path
    urls << user_register_path
    urls << user_register_user_path
    urls << user_login_path
    urls << user_logout_path
    urls << user_save_path
    urls << user_save_dialog_path
    urls << user_change_password_path
    urls << user_password_dialog_path
    urls << user_confirm_path
    urls << user_lock_path
    urls << user_admin_path
    urls << user_delete_path
    urls << user_tokens_path
    urls << user_do_login_path
    urls << group_show_path
    urls << group_add_path
    urls << group_save_path
    urls << group_tokens_path
    urls << group_edit_path
    urls << home_path
    urls << home_my_work_path
    urls << home_list_my_path
    urls << home_requests_path
    urls << home_home_project_path
    urls << home_remove_watched_project_path
    urls << apidocs_path
    urls << apidocs_index_path

    urls.each do |u|
      begin
        get u
      rescue ActionController::RoutingError => e
        next if e.message =~ %r{Required Parameter.*missing}
        next if e.message =~ %r{No route matches \[GET\]}
        next if e.message =~ %r{Expected AJAX call}
        next if e.message =~ %r{expected application/rss}
        raise e
      end
      next if @response.response_code == 302
      # missing parameters are mapped to 404
      next if @response.response_code == 404
      if @response.response_code == 200
        next if @response.content_type == "application/xml"
        source = @response.body
        next if source =~ %r{<urlset xmlns=}
        next if source =~ %r{<sitemapindex xmlns=}
        body = Nokogiri::HTML::Document.parse(source).root
        if body.css("a#header-logo").empty?
          puts "URL #{u} #{source}"
        end
      else
        raise "#{u} had a response code of #{@response.response_code}"
      end
    end
  end
  
end

