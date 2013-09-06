require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"
require 'find'
require 'tempfile'

RAILS_BASE_DIRS = ['app', 'db', 'config', 'lib', 'test'].map { |dir| Rails.root.join(dir) }

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
    IO.popen("ruby -cv - 2>&1 > /dev/null | grep '^-' > #{tmpfile.path}", "w") do |io|
      io.write("# encoding: utf-8\n")
      @ruby_files.each do |ruby_file|
        lines = File.open(ruby_file).read
        begin
          io.write(lines)
          io.write("\n")
        rescue Errno::EPIPE
        end
      end
    end
    tmpfile.open
    line = tmpfile.read
    tmpfile.close
    return if line.empty?
    puts "ruby -cv gave output: testing syntax of each ruby file... #{line}"
    @ruby_files.each do |ruby_file|
      IO.popen("ruby -cv #{ruby_file} 2>&1 > /dev/null | grep #{Rails.root}") do |io|
        line = io.read
        unless line.empty?
          puts line
          assert(false, "ruby -cv #{ruby_file} gave output\n#{line}")
        end
      end
    end
    puts "done"
  end

  # Checks that no 'debugger' statement is present in ruby code
  test "no ruby debugger statement" do
    @ruby_files.each do |ruby_file|
      File.open(ruby_file).each_with_index do |line, number|
        assert(false, "#{ruby_file}:#{number + 1} 'debugger' statement found!") if line.match(/^\s*debugger/)
      end
    end
  end

  # our current exceptions
  BlackList = {
      'MaintenanceHelper#do_branch' => 1125.32,
      'Project#update_from_xml' => 456.54,
      'ApplicationController#extract_user' => 399.23,
      'BsRequestAction#check_newstate!' => 378.58,
      'BsRequestAction#create_expand_package' => 350.8,
      'Webui::ProjectsController#status' => 346.5,
      'RequestController#check_request_change' => 257.26,
      'Package#buildstatus' => 238.95,
      'MaintenanceHelper#release_package' => 233.59,
      'Package#private_set_package_kind' => 223.09,
      'BsRequestAction#check_action_permission!' => 221.25,
      'User::find_with_ldap' => 193.31,
      'RequestController#command_changestate' => 191.97,
      'SourceController#project_meta' => 191.91,
      'PersonController#internal_register' => 185.66,
      'BsRequest#change_review_state' => 177.4,
      'BsRequestActionMaintenanceIncident#merge_into_maintenance_incident' => 166.26,
      'SourceController#update_file' => 163.79,
      'ProjectStatusHelper::calc_status' => 159.25,
      'MaintenanceIncident#getUpdateinfoId' => 151.95,
      'PersonController#userinfo' => 149.28,
      'IssueTracker#private_fetch_issues' => 147.27,
      'Maintainership#extract_maintainer' => 144.49,
      'BsRequest#events' => 143.76,
      'SourceController#project_command_copy' => 140.04,
      'BsRequestActionSubmit#execute_accept' => 136.79,
      'BsRequestAction#default_reviewers' => 135.96,
      'WizardController#package_wizard' => 135.16,
      'PublicController#binary_packages' => 134.24,
      'BsRequest#webui_actions' => 130.13,
      'BuildController#project_index' => 129.0,
      'BuildController#file' => 127.42,
      'BsRequest::new_from_xml' => 126.34,
      'Project#branch_to_repositories_from' => 117.4,
      'ConfigurationsController#update' => 110.96,
      'RequestController#create_create' => 110.65,
      'SubmitRequestSourceDiff::ActionSourceDiffer#diff_for_source' => 60.19,
      'User::render_grouplist_ldap' => 107.88,
      'SearchController#find_attribute' => 104.54,
      'Webui::ProjectsController#infos' => 104.05,
      'StatusController#update_workerstatus_cache' => 102.09,
      'IssueTrackersController#update' => 100.78,
      'User#state_transition_allowed?' => 100.14,
      'Package::get_by_project_and_name' => 96.92,
      'SourceController#package_meta' => 95.53,
      'RequestController#render_request_collection' => 92.82,
      'BsRequestActionMaintenanceRelease#check_permissions!' => 91.4,
      'SourceController#show_project' => 88.97,
      'StatusController#messages' => 88.52,
      'BsRequestAction#store_from_xml' => 88.01,
      'SourceController#delete_package' => 72.46,
      'AttributeController#attribute_definition' => 87.7,
      'Repository#cleanup_before_destroy' => 85.53,
      'BsRequest#check_newstate!' => 84.89,
      'HasAttributes#render_main_attributes' => 81.58,
      'ProjectStatusHelper::check_md5' => 80.51,
      'BsRequestAction#check_sanity' => 78.06,
      'Channel::verify_xml!' => 76.81,
      'StatusController#bsrequest' => 75.82,
      'MessageController#index' => 74.13,
      'SearchController#search' => 72.92,
      'StatisticsController#active_request_creators' => 71.14,
      'FullTextSearch#search' => 70.26,
      'Channel#update_from_xml' => 69.48,
      'SourceController#package_command_copy' => 69.4,
      'User::initialize_ldap_con' => 69.08,
      'TagController#tagcloud' => 68.37,
      'TagController#update_tags_by_object_and_user' => 67.76,
      'Project#cleanup_before_destroy' => 67.17,
      'SourceController#package_command' => 65.31,
      'MaintenanceHelper#create_new_maintenance_incident' => 64.93,
      'AttributeController#namespace_definition' => 64.52,
      'User::update_entry_ldap' => 64.21,
      'Maintainership#find_assignees' => 64.17,
      'SourceController#delete_project' => 64.16,
      'SearchHelper#search_owner' => 63.93,
      'PackInfo#to_xml' => 63.64,
      'Attrib#update_from_xml' => 62.88,
      'AttributeController#find_attribute_container' => 62.42,
      'BsRequestAction#find_reviewers' => 61.68,
      'User#has_local_role?' => 60.69,
      'IssueTracker#update_issues' => 60.49,
      'Package#add_channels' => 60.1,
      'Distribution::all_including_remotes' => 58.7,
      'SourceController#project_command_undelete' => 58.11,
      'ApplicationController#forward_from_backend' => 57.96,
      'User#can_create_attribute_in?' => 57.78,
      'StatisticsController#rating' => 57.46,
      'BsRequestAction#notify_params' => 56.35,
      'ArchitecturesController#index' => 55.94,
      'SourceController#project_pubkey' => 54.65,
      'Project::check_access?' => 54.05,
      'SourceController#project_command_set_flag' => 53.57,
      'Project::get_by_name' => 53.44,
      'IssueTrackersController#create' => 53.05,
      'Issue#render_body' => 52.78,
      'HasAttributes#check_attrib!' => 52.45,
      'Package#resolve_devel_package' => 52.33,
      'SourceController#verify_repos_match!' => 52.26,
      'ProjectStatusHelper::update_jobhistory' => 50.29,
      'StatusHelper::resample' => 49.79,
      'MaintenanceIncident#project_name' => 49.41,
      'Project#expand_flags' => 48.97,
      'User::new_entry_ldap' => 48.87,
      'Relationship#check_sanity' => 48.62,
      'RequestController#command_diff' => 48.55,
      'ApplicationController#render_error' => 48.45,
      'PersonController#index' => 48.28,
      'SourceController#project_command_unlock' => 47.79,
      'Project#update_product_autopackages' => 47.69,
      'BsRequestAction#expand_targets' => 46.89,
      'Project#do_project_release' => 46.59,
      'BuildController#result' => 46.16,
      'User#has_local_permission?' => 45.84,
      'PersonController#change_password' => 45.67,
      'BsRequest#change_state' => 43.81,
      'BsRequest#remove_reviews' => 44.57,
      'AttributeController#cmd_attribute' => 44.22,
      'StatusController#history' => 44.12,
      'StatusHistoryRescaler#cleanup' => 43.59,
      'BsRequest#render_xml' => 42.98,
      'Maintainership#find_containers' => 42.72,
      'StatusController#find_relationships_for_packages' => 42.59,
      'SourceController#project_command' => 42.44,
      'HasRelationships#update_generic_relationships' => 42.42,
      'AttributeController#delete_attribute' => 42.24,
      'TagController#project_tags' => 42.13,
      'TagController#package_tags' => 42.02,
      'SourceController#package_command_release' => 41.75,
      'Tagcloud#initialize' => 41.73,
      'SourceController#project_config' => 41.69,
      'Package#find_linking_packages' => 40.68,
      'SourceController#private_remove_repositories' => 40.37
  }

  test "code complexity" do
    require "flog_cli"
    flog = Flog.new :continue => true
    dirs = %w(app/controllers app/views app/models app/mixins app/indices app/helpers)
    files = FlogCLI.expand_dirs_to_files(*dirs)
    flog.flog(*files)

    black = BlackList.dup
    flog.calculate
    mismatches = []

    flog.each_by_score do |class_method, score, call_list|
      break if score < 40 # they are sorted
      next if class_method.end_with? "#none"
      score = Integer(score * 100)
      score = score / Float(100)

      oldscore = black.delete class_method
      if oldscore.nil?
        mismatches << "'#{class_method}' => #{score}, is not in the blacklist"
        next
      end
                          # don't want to be too strict here
      next if (oldscore-score).abs < 0.5
      mismatches << "  '#{class_method}' => #{score}, # oldscore=#{oldscore}"
    end

    assert mismatches.empty?, mismatches.join("\n")
    assert black.empty?, "Some functions are no longer complex and need to removed from black list - #{black.keys.inspect}"
  end
end
