require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"
require 'nokogiri'

class AllRoutesTest < ActionController::IntegrationTest

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
    urls << package_show_path
    urls << package_linking_packages_path
    urls << package_dependency_path
    urls << package_binary_path
    urls << package_binaries_path
    urls << package_users_path
    urls << package_requests_path
    urls << package_statistics_path
    urls << package_commit_path
    urls << package_revisions_path
    urls << package_submit_request_dialog_path
    urls << package_submit_request_path
    urls << package_add_person_path
    urls << package_add_group_path
    urls << package_rdiff_path
    urls << package_wizard_new_path
    urls << package_wizard_path
    urls << package_save_new_path
    urls << package_branch_dialog_path
    urls << package_branch_path
    urls << package_save_new_link_path
    urls << package_save_path
    urls << package_delete_dialog_path
    urls << package_remove_path
    urls << package_add_file_path
    urls << package_save_file_path
    urls << package_remove_file_path
    urls << package_save_person_path
    urls << package_save_group_path
    urls << package_remove_role_path
    urls << package_view_file_path
    urls << package_save_modified_file_path
    urls << package_rawsourcefile_path
    urls << package_rawlog_path
    urls << package_live_build_log_path
    urls << package_update_build_log_path
    urls << package_abort_build_path
    urls << package_trigger_rebuild_path
    urls << package_wipe_binaries_path
    urls << package_devel_project_path
    urls << package_buildresult_path
    urls << package_rpmlint_result_path
    urls << package_rpmlint_log_path
    urls << package_meta_path
    urls << package_save_meta_path
    urls << package_attributes_path
    urls << package_edit_path
    urls << package_repositories_path
    urls << package_change_flag_path
    urls << package_import_spec_path
    urls << package_files_path
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
    urls << project_autocomplete_projects_path
    urls << project_autocomplete_incidents_path
    urls << project_autocomplete_packages_path
    urls << project_autocomplete_repositories_path
    urls << project_users_path
    urls << project_subprojects_path
    urls << project_attributes_path
    urls << project_new_path
    urls << project_new_incident_path
    urls << project_new_package_path
    urls << project_new_package_branch_path
    urls << project_incident_request_dialog_path
    urls << project_new_incident_request_path
    urls << project_release_request_dialog_path
    urls << project_new_release_request_path
    urls << project_show_path
    urls << project_load_releasetargets_path
    urls << project_linking_projects_path
    urls << project_add_repository_from_default_list_path
    urls << project_add_repository_path
    urls << project_add_person_path
    urls << project_add_group_path
    urls << project_buildresult_path
    urls << project_delete_dialog_path
    urls << project_delete_path
    urls << project_edit_repository_path
    urls << project_update_target_path
    urls << project_repositories_path
    urls << project_repository_state_path
    urls << project_rebuild_time_path
    urls << project_rebuild_time_png_path
    urls << project_packages_path
    urls << project_requests_path
    urls << project_save_new_path
    urls << project_save_path
    urls << project_save_targets_path
    urls << project_remove_target_request_dialog_path
    urls << project_remove_target_request_path
    urls << project_remove_target_path
    urls << project_remove_path_from_target_path
    urls << project_move_path_up_path
    urls << project_move_path_down_path
    urls << project_save_person_path
    urls << project_save_group_path
    urls << project_remove_role_path
    urls << project_remove_person_path
    urls << project_remove_group_path
    urls << project_monitor_path
    urls << project_package_buildresult_path
    urls << project_toggle_watch_path
    urls << project_meta_path
    urls << project_save_meta_path
    urls << project_prjconf_path
    urls << project_save_prjconf_path
    urls << project_change_flag_path
    urls << project_clear_failed_comment_path
    urls << project_edit_path
    urls << project_edit_comment_form_path
    urls << project_edit_comment_path
    urls << project_status_path
    urls << project_maintained_projects_path
    urls << project_add_maintained_project_dialog_path
    urls << project_add_maintained_project_path
    urls << project_remove_maintained_project_path
    urls << project_maintenance_incidents_path
    urls << project_list_incidents_path
    urls << project_unlock_dialog_path
    urls << project_unlock_path
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
    urls << user_save_dialog_path
    urls << user_save_path
    urls << user_confirm_path
    urls << user_lock_path
    urls << user_admin_path
    urls << user_delete_path
    urls << user_change_password_path
    urls << user_autocomplete_path
    urls << user_do_login_path
    urls << user_edit_path
    urls << user_register_path
    urls << user_register_user_path
    urls << user_login_path
    urls << user_logout_path
    urls << group_add_path
    urls << group_save_path
    urls << group_autocomplete_path
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

