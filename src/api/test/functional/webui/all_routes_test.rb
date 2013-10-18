require 'test_helper'
require 'nokogiri'

class Webui::AllRoutesTest < Webui::IntegrationTest

  test 'visit all routes' do
    # rake routes | cut -b-40 | sed -e 's,  *,,g' | grep -v '^$' | sed -e 's,^\(.*\),    urls << webui_engine.\1_path,' 
    urls = Array.new
    urls << webui_engine.main_sitemap_path
    urls << webui_engine.main_sitemap_projects_path
    urls << webui_engine.main_sitemap_projects_packages_path
    urls << webui_engine.main_sitemap_projects_prjconf_path
    urls << webui_engine.main_add_news_path
    urls << webui_engine.main_delete_message_path
    urls << webui_engine.attribute_edit_path
    urls << webui_engine.attribute_save_path
    urls << webui_engine.attribute_delete_path
    urls << webui_engine.configuration_path
    urls << webui_engine.configuration_users_path
    urls << webui_engine.configuration_groups_path
    urls << webui_engine.configuration_connect_instance_path
    urls << webui_engine.configuration_save_instance_path
    urls << webui_engine.configuration_update_configuration_path
    urls << webui_engine.configuration_update_architectures_path
    urls << webui_engine.driver_update_create_path
    urls << webui_engine.driver_update_edit_path
    urls << webui_engine.driver_update_save_path
    urls << webui_engine.driver_update_binaries_path
    urls << webui_engine.monitor_path
    urls << webui_engine.monitor_old_path
    urls << webui_engine.url_for(controller: '/webui/package', action: :show, project: 'kde4', package: 'kdelibs')
    urls << webui_engine.url_for(controller: '/webui/package', action: :dependency, project: 'kde4', package: 'kdelibs')
    urls << webui_engine.url_for(controller: '/webui/package', action: :binary, project: 'kde4', package: 'kdelibs')
    urls << webui_engine.url_for(controller: '/webui/package', action: :binaries, project: 'kde4', package: 'kdelibs')
    urls << webui_engine.url_for(controller: '/webui/package', action: :users, project: 'kde4', package: 'kdelibs')
    urls << webui_engine.url_for(controller: '/webui/package', action: :requests, project: 'kde4', package: 'kdelibs')
    urls << webui_engine.url_for(controller: '/webui/package', action: :statistics, project: 'kde4', package: 'kdelibs')
    urls << webui_engine.url_for(controller: '/webui/package', action: :commit, project: 'kde4', package: 'kdelibs')
    urls << webui_engine.url_for(controller: '/webui/package', action: :revisions, project: 'kde4', package: 'kdelibs')
    urls << webui_engine.url_for(controller: '/webui/package', action: :submit_request, project: 'kde4', package: 'kdelibs')
    urls << webui_engine.url_for(controller: '/webui/package', action: :add_person, project: 'kde4', package: 'kdelibs')
    urls << webui_engine.url_for(controller: '/webui/package', action: :add_group, project: 'kde4', package: 'kdelibs')
    urls << webui_engine.url_for(controller: '/webui/package', action: :rdiff, project: 'kde4', package: 'kdelibs')
    urls << webui_engine.url_for(controller: '/webui/package', action: :save_new, project: 'kde4', package: 'kdelibs')
    urls << webui_engine.url_for(controller: '/webui/package', action: :branch, project: 'kde4', package: 'kdelibs')
    urls << webui_engine.url_for(controller: '/webui/package', action: :save_new_link, project: 'kde4', package: 'kdelibs')
    urls << webui_engine.url_for(controller: '/webui/package', action: :save, project: 'kde4', package: 'kdelibs')
    urls << webui_engine.url_for(controller: '/webui/package', action: :remove, project: 'kde4', package: 'kdelibs')
    urls << webui_engine.url_for(controller: '/webui/package', action: :add_file, project: 'kde4', package: 'kdelibs')
    urls << webui_engine.url_for(controller: '/webui/package', action: :save_file, project: 'kde4', package: 'kdelibs')
    urls << webui_engine.url_for(controller: '/webui/package', action: :remove_file, project: 'kde4', package: 'kdelibs')
    urls << webui_engine.url_for(controller: '/webui/package', action: :save_person, project: 'kde4', package: 'kdelibs')
    urls << webui_engine.url_for(controller: '/webui/package', action: :save_group, project: 'kde4', package: 'kdelibs')
    urls << webui_engine.url_for(controller: '/webui/package', action: :remove_role, project: 'kde4', package: 'kdelibs')
    urls << webui_engine.url_for(controller: '/webui/package', action: :view_file, project: 'kde4', package: 'kdelibs')
    urls << webui_engine.url_for(controller: '/webui/package', action: :save_modified_file, project: 'kde4', package: 'kdelibs')
    urls << webui_engine.url_for(controller: '/webui/package', action: :abort_build, project: 'kde4', package: 'kdelibs')
    urls << webui_engine.url_for(controller: '/webui/package', action: :trigger_rebuild, project: 'kde4', package: 'kdelibs')
    urls << webui_engine.url_for(controller: '/webui/package', action: :wipe_binaries, project: 'kde4', package: 'kdelibs')
    urls << webui_engine.url_for(controller: '/webui/package', action: :meta, project: 'kde4', package: 'kdelibs')
    urls << webui_engine.url_for(controller: '/webui/package', action: :save_meta, project: 'kde4', package: 'kdelibs')
    urls << webui_engine.url_for(controller: '/webui/package', action: :attributes, project: 'kde4', package: 'kdelibs')
    urls << webui_engine.url_for(controller: '/webui/package', action: :edit, project: 'kde4', package: 'kdelibs')
    urls << webui_engine.url_for(controller: '/webui/package', action: :repositories, project: 'kde4', package: 'kdelibs')
    urls << webui_engine.url_for(controller: '/webui/package', action: :change_flag, project: 'kde4', package: 'kdelibs')
    urls << webui_engine.url_for(controller: '/webui/package', action: :import_spec, project: 'kde4', package: 'kdelibs')
    urls << webui_engine.patchinfo_new_patchinfo_path
    urls << webui_engine.patchinfo_updatepatchinfo_path
    urls << webui_engine.patchinfo_edit_patchinfo_path
    urls << webui_engine.patchinfo_read_patchinfo_path
    urls << webui_engine.patchinfo_save_path
    urls << webui_engine.patchinfo_remove_path
    urls << webui_engine.patchinfo_new_tracker_path
    urls << webui_engine.patchinfo_get_issue_sum_path
    urls << webui_engine.project_path
    urls << webui_engine.url_for(controller: '/webui/project', action: :users, project: 'kde4')
    urls << webui_engine.url_for(controller: '/webui/project', action: :subprojects, project: 'kde4')
    urls << webui_engine.url_for(controller: '/webui/project', action: :attributes, project: 'kde4')
    urls << webui_engine.url_for(controller: '/webui/project', action: :new, project: 'kde4')
    urls << webui_engine.url_for(controller: '/webui/project', action: :new_incident, project: 'kde4')
    urls << webui_engine.url_for(controller: '/webui/project', action: :new_package, project: 'kde4')
    urls << webui_engine.url_for(controller: '/webui/project', action: :new_package_branch, project: 'kde4')
    urls << webui_engine.url_for(controller: '/webui/project', action: :new_incident_request, project: 'kde4')
    urls << webui_engine.url_for(controller: '/webui/project', action: :new_release_request, project: 'kde4')
    urls << webui_engine.url_for(controller: '/webui/project', action: :show, project: 'kde4')
    urls << webui_engine.url_for(controller: '/webui/project', action: :add_repository_from_default_list, project: 'kde4')
    urls << webui_engine.url_for(controller: '/webui/project', action: :add_repository, project: 'kde4')
    urls << webui_engine.url_for(controller: '/webui/project', action: :add_person, project: 'kde4')
    urls << webui_engine.url_for(controller: '/webui/project', action: :add_group, project: 'kde4')
    urls << webui_engine.url_for(controller: '/webui/project', action: :delete, project: 'kde4')
    urls << webui_engine.url_for(controller: '/webui/project', action: :update_target, project: 'kde4')
    urls << webui_engine.url_for(controller: '/webui/project', action: :repositories, project: 'kde4')
    urls << webui_engine.url_for(controller: '/webui/project', action: :repository_state, project: 'kde4')
    urls << webui_engine.url_for(controller: '/webui/project', action: :packages, project: 'kde4')
    urls << webui_engine.url_for(controller: '/webui/project', action: :requests, project: 'kde4')
    urls << webui_engine.url_for(controller: '/webui/project', action: :save_new, project: 'kde4')
    urls << webui_engine.url_for(controller: '/webui/project', action: :save, project: 'kde4')
    urls << webui_engine.url_for(controller: '/webui/project', action: :save_targets, project: 'kde4')
    urls << webui_engine.url_for(controller: '/webui/project', action: :remove_target_request, project: 'kde4')
    urls << webui_engine.url_for(controller: '/webui/project', action: :remove_target, project: 'kde4')
    urls << webui_engine.url_for(controller: '/webui/project', action: :move_path_up, project: 'kde4')
    urls << webui_engine.url_for(controller: '/webui/project', action: :move_path_down, project: 'kde4')
    urls << webui_engine.url_for(controller: '/webui/project', action: :save_person, project: 'kde4')
    urls << webui_engine.url_for(controller: '/webui/project', action: :save_group, project: 'kde4')
    urls << webui_engine.url_for(controller: '/webui/project', action: :remove_role, project: 'kde4')
    urls << webui_engine.url_for(controller: '/webui/project', action: :remove_person, project: 'kde4')
    urls << webui_engine.url_for(controller: '/webui/project', action: :remove_group, project: 'kde4')
    urls << webui_engine.url_for(controller: '/webui/project', action: :monitor, project: 'kde4')
    urls << webui_engine.url_for(controller: '/webui/project', action: :toggle_watch, project: 'kde4')
    urls << webui_engine.url_for(controller: '/webui/project', action: :meta, project: 'kde4')
    urls << webui_engine.url_for(controller: '/webui/project', action: :save_meta, project: 'kde4')
    urls << webui_engine.url_for(controller: '/webui/project', action: :prjconf, project: 'kde4')
    urls << webui_engine.url_for(controller: '/webui/project', action: :save_prjconf, project: 'kde4')
    urls << webui_engine.url_for(controller: '/webui/project', action: :change_flag, project: 'kde4')
    urls << webui_engine.url_for(controller: '/webui/project', action: :clear_failed_comment, project: 'kde4')
    urls << webui_engine.url_for(controller: '/webui/project', action: :edit, project: 'kde4')
    urls << webui_engine.url_for(controller: '/webui/project', action: :edit_comment, project: 'kde4')
    urls << webui_engine.url_for(controller: '/webui/project', action: :status, project: 'kde4')
    urls << webui_engine.url_for(controller: '/webui/project', action: :maintained_projects, project: 'kde4')
    urls << webui_engine.url_for(controller: '/webui/project', action: :add_maintained_project_dialog, project: 'kde4')
    urls << webui_engine.url_for(controller: '/webui/project', action: :add_maintained_project, project: 'kde4')
    urls << webui_engine.url_for(controller: '/webui/project', action: :remove_maintained_project, project: 'kde4')
    urls << webui_engine.url_for(controller: '/webui/project', action: :maintenance_incidents, project: 'kde4')
    urls << webui_engine.url_for(controller: '/webui/project', action: :unlock, project: 'kde4')
    urls << webui_engine.request_add_reviewer_path
    urls << webui_engine.request_modify_review_path
    urls << webui_engine.request_sourcediff_path
    urls << webui_engine.request_changerequest_path
    urls << webui_engine.request_list_path
    urls << webui_engine.request_list_small_path
    urls << webui_engine.request_delete_request_path
    urls << webui_engine.request_add_role_request_path
    urls << webui_engine.request_set_bugowner_request_path
    urls << webui_engine.request_change_devel_request_path
    urls << webui_engine.request_set_incident_path
    urls << webui_engine.search_path
    urls << webui_engine.search_owner_path
    urls << webui_engine.user_register_path
    urls << webui_engine.user_register_user_path
    urls << webui_engine.user_login_path
    urls << webui_engine.user_logout_path
    urls << webui_engine.user_save_path
    urls << webui_engine.user_change_password_path
    urls << webui_engine.user_confirm_path
    urls << webui_engine.user_lock_path
    urls << webui_engine.user_admin_path
    urls << webui_engine.user_delete_path
    urls << webui_engine.user_tokens_path
    urls << webui_engine.user_do_login_path
    urls << webui_engine.group_add_path
    urls << webui_engine.group_save_path
    urls << webui_engine.group_tokens_path
    urls << webui_engine.group_edit_path
    urls << webui_engine.home_path
    urls << webui_engine.home_my_work_path
    urls << webui_engine.home_list_my_path
    urls << webui_engine.home_requests_path
    urls << webui_engine.home_home_project_path
    urls << webui_engine.home_remove_watched_project_path
    urls << webui_engine.apidocs_path
    urls << webui_engine.apidocs_index_path

    urls.each do |u|
      begin
        get u, {}, { 'CONTENT_TYPE' => ''}
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
        next if %w(application/json application/xml).include? @response.content_type
        source = @response.body
        next if source =~ %r{<urlset xmlns=}
        next if source =~ %r{<sitemapindex xmlns=}
        body = Nokogiri::HTML::Document.parse(source).root
        if body.css('a#header-logo').empty?
          puts "URL #{u} #{source}"
        end
      else
        raise "#{u} had a response code of #{@response.response_code}"
      end
    end
  end
  
end

