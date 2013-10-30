require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"
require 'find'
require 'tempfile'

RAILS_BASE_DIRS = ['app', 'db', 'config', 'lib', 'test', 'webui' ].map { |dir| Rails.root.join(dir) }

class CodeQualityTest < ActiveSupport::TestCase
  def setup
    @ruby_files = []
    RAILS_BASE_DIRS.each do |base_dir|
      Find.find(base_dir) do |path|
        @ruby_files << path if FileTest.file?(path) and path.end_with?('.rb')
      end
    end
  end

  # Does a static syntax check, but doesn't interpret the code
  test "static ruby syntax" do
    # fast test first
    tmpfile = Tempfile.new('output')
    tmpfile.close
    linenr = 1
    linenrs = []
    IO.popen("ruby -cv - 2>&1 > /dev/null | grep '^-' > #{tmpfile.path}", "w") do |io|
      io.write("# encoding: utf-8\n")
      @ruby_files.each do |ruby_file|
        lines = File.open(ruby_file).readlines
        begin
          io.write(lines.join)
          io.write("\n")
        rescue Errno::EPIPE
        end
	linenrs << [ruby_file, linenr]
	linenr += lines.size + 1
      end
    end
    tmpfile.open
    lines = tmpfile.readlines
    tmpfile.close

    lines.each do |output|
      failed = Integer(output.split(':')[1])
      failedfile = nil
      linenrs.each do |ruby_file, line|
        break if line > failed 
        failedfile = ruby_file
      end
      IO.popen("ruby -cv #{failedfile} 2>&1 > /dev/null | grep #{Rails.root}") do |io|
        line = io.read
        unless line.empty?
          assert(false, "ruby -cv gave output\n#{line}")
        end
      end
    end
  end

  # Checks that no 'debugger' statement is present in ruby code
  test "no ruby debugger statement" do
    @ruby_files.each do |ruby_file|
      File.open(ruby_file).each_with_index do |line, number|
        assert(false, "#{ruby_file}:#{number + 1} 'debugger' statement found!") if line.match(/^\s*debugger/)
	assert(false, "#{ruby_file}:#{number + 1} 'save_and_open_page' statement found!") if line.match(/^\s*save_and_open_page/)
      end
    end
  end

  # our current exceptions
  BlackList = {
      'ApplicationController#extract_ldap_user' => 123.29,
      'ApplicationController#extract_proxy_user' => 65.48,
      'ApplicationController#forward_from_backend' => 57.96,
      'ArchitecturesController#index' => 55.94,
      'Attrib#update_from_xml' => 62.88,
      'AttributeController#attribute_definition' => 87.7,
      'AttributeController#find_attribute_container' => 62.42,
      'AttributeController#namespace_definition' => 64.52,
      'BsRequest#change_review_state' => 177.4,
      'BsRequest#check_newstate!' => 84.89,
      'BsRequest#events' => 143.76,
      'BsRequest#webui_actions' => 130.13,
      'BsRequest::new_from_xml' => 126.34,
      'BsRequestAction#check_action_permission!' => 221.25,
      'BsRequestAction#check_newstate!' => 372.38,
      'BsRequestAction#check_sanity' => 78.06,
      'BsRequestAction#create_expand_package' => 324.93,
      'BsRequestAction#default_reviewers' => 135.96,
      'BsRequestAction#find_reviewers' => 61.68,
      'BsRequestAction#notify_params' => 56.35,
      'BsRequestAction#store_from_xml' => 88.01,
      'BsRequestActionMaintenanceIncident#merge_into_maintenance_incident' => 166.26,
      'BsRequestActionMaintenanceRelease#check_permissions!' => 91.4,
      'BsRequestActionSubmit#execute_accept' => 136.79,
      'BuildController#file' => 127.42,
      'BuildController#project_index' => 129.0,
      'Channel#update_from_xml' => 69.48,
      'Channel::verify_xml!' => 76.81,
      'ConfigurationsController#update' => 85.63,
      'Distribution::all_including_remotes' => 58.7,
      'HasAttributes#check_attrib!' => 52.45,
      'HasAttributes#render_main_attributes' => 81.58,
      'IssueTracker#update_issues' => 60.49,
      'IssueTrackersController#create' => 53.05,
      'IssueTrackersController#update' => 100.78,
      'MaintenanceHelper#create_new_maintenance_incident' => 64.93,
      'MaintenanceHelper#do_branch' => 1118,
      'MaintenanceHelper#release_package' => 227.71,
      'MaintenanceIncident#getUpdateinfoId' => 151.95,
      'Owner::find_assignees' => 71.55,
      'Owner::search' => 67.56,
      'Owner::extract_maintainer' => 155.65,
      'PackInfo#to_xml' => 53.64,
      'Package#resolve_devel_package' => 52.33,
      'PersonController#internal_register' => 108.84,
      'PersonController#put_userinfo' => 56.38,
      'Project#branch_to_repositories_from' => 126.41,
      'Project#cleanup_before_destroy' => 67.17,
      'Project#update_from_xml' => 442.36,
      'Project::check_access?' => 54.05,
      'Project::get_by_name' => 53.44,
      'ProjectStatusCalculator#calc_status' => 74.59,
      'PublicController#binary_packages' => 134.24,
      'Repository#cleanup_before_destroy' => 85.53,
      'RequestController#check_request_change' => 257.26,
      'RequestController#command_changestate' => 190.9,
      'RequestController#create_create' => 110.65,
      'RequestController#render_request_collection' => 92.82,
      'SearchController#find_attribute' => 97.33,
      'SearchController#search' => 67.14,
      'SourceController#delete_package' => 65.55,
      'SourceController#delete_project' => 64.16,
      'SourceController#package_command' => 65.31,
      'SourceController#package_command_copy' => 64.36,
      'SourceController#project_command_copy' => 140.04,
      'SourceController#project_command_set_flag' => 53.57,
      'SourceController#project_command_undelete' => 58.11,
      'SourceController#update_project_meta' => 139.28,
      'SourceController#update_file' => 97.26,
      'SourceController#verify_repos_match!' => 52.26,
      'StatisticsController#active_request_creators' => 71.14,
      'StatisticsController#rating' => 57.46,
      'SubmitRequestSourceDiff::ActionSourceDiffer#diff_for_source' => 60.19,
      'TagController#tagcloud' => 68.37,
      'TagController#update_tags_by_object_and_user' => 67.76,
      'User::register' => 80.9,
      'User#can_create_attribute_in?' => 57.78,
      'User#state_transition_allowed?' => 100.14,
      'UserLdapStrategy::find_with_ldap' => 181.11,
      'UserLdapStrategy::initialize_ldap_con' => 64.05,
      'UserLdapStrategy::render_grouplist_ldap' => 100.3,
      'UserLdapStrategy::update_entry_ldap' => 59.56,
      'WizardController#package_wizard' => 135.16,
      'Webui::PatchinfoController#save' => 248.01,
      'Webui::BsRequest::make_stub' => 233.83,
      'Webui::ProjectController#status_check_package' => 187.14,
      'Webui::ProjectController#monitor' => 154.83,
      'Webui::PackageController#save_new_link' => 136.05,
      'Webui::WebuiHelper#flag_status' => 93.0,
      'Webui::ProjectController#save_targets' => 127.29,
      'Webui::PackageController#save_file' => 117.16,
      'WebuiProject#release_targets_ng' => 104.14,
      'Webui::PackageController#submit_request' => 103.71,
      'Webui::PatchinfoController#read_patchinfo' => 103.22,
      'Webui::ProjectController#rebuild_time' => 99.43,
      'Webui::SearchController#set_parameters' => 98.04,
      'Webui::DriverUpdateController#save' => 97.16,
      'Webui::ProjectController#save_new' => 94.35,
      'Webui::ProjectController#repository_state' => 92.78,
      'Webui::BsRequest::prepare_list_path' => 88.77,
      'Webui::WebuiController#mobile_request?' => 84.33,
      'Webui::PackageController#fill_status_cache' => 81.3,
      'Webui::PackageController#require_package' => 80.11,
      'Webui::WebuiController#validate_xhtml' => 78.83,
      'Webui::RequestController#show' => 72.45,
      'Webui::PackageController#save_new' => 77.0,
      'Webui::PatchinfoController#new_tracker' => 68.43,
      'Webui::ProjectController#status' => 67.37,
      'Webui::MonitorController#events' => 59.75,
      'Webui::ProjectHelper#show_status_comment' => 64.97,
      'Webui::RequestController#set_bugowner_request' => 64.93,
      'Webui::UserController#do_login' => 62.12,
      'Webui::PackageController#show' => 61.72,
      'Webui::HomeController#requests' => 59.67,
      'Webui::PatchinfoController#get_issue_sum' => 56.69,
      'Webui::AttributeController#edit' => 55.09,
      'Webui::MonitorController#index' => 54.45,
      'Webui::BsRequest::list_ids' => 52.98,
      'Webui::BsRequest::modifyReview' => 52.84,
      'Webui::BsRequest::addReview' => 52.7,
      'Webui::PackageController#branch' => 50.36,
  }

  test "code complexity" do
    require "flog_cli"
    flog = Flog.new :continue => true
    dirs = %w(app/controllers app/views app/models app/mixins app/indices app/helpers app/jobs webui/app/controllers webui/app/models webui/app/helpers)
    files = FlogCLI.expand_dirs_to_files(*dirs)
    flog.flog(*files)

    black = BlackList.dup
    flog.calculate
    mismatches = []

    flog.each_by_score do |class_method, score, call_list|
      break if score < 50 # they are sorted
      next if class_method.end_with? "#none"
      score = Integer(score * 100)
      score = score / Float(100)

      oldscore = black.delete class_method
      if oldscore.nil?
        mismatches << "'#{class_method}' => #{score}, "
        next
      end
      # don't want to be too strict here
      next if (oldscore-score).abs < 2
      error = "  '#{class_method}' => #{score}, # oldscore=#{oldscore}"
      if score > oldscore
        mismatches << error
      else
	# scare them but don't fail
        puts error
      end
    end

    assert mismatches.empty?, mismatches.join("\n")
    puts "Some functions are no longer complex and need to removed from black list - #{black.keys.inspect}" unless black.empty?
  end
end
