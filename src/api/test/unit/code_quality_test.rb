require File.expand_path(File.dirname(__FILE__) + '/..') + '/test_helper'
require 'find'
require 'tempfile'

RAILS_BASE_DIRS = %w(app db config lib test).map { |dir| Rails.root.join(dir) }

class CodeQualityTest < ActiveSupport::TestCase
  def setup
    @ruby_files = []
    RAILS_BASE_DIRS.each do |base_dir|
      Find.find(base_dir.to_s) do |path|
        @ruby_files << path if FileTest.file?(path) and path.end_with?('.rb')
      end
    end
  end

  # Does a static syntax check, but doesn't interpret the code
  test 'static ruby syntax' do
    # fast test first
    tmpfile = Tempfile.new('output')
    tmpfile.close
    linenr = 1
    linenrs = []
    IO.popen("ruby -cv - 2>&1 > /dev/null | grep '^-' > #{tmpfile.path}", 'w') do |io|
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
  test 'no ruby debugger statement' do
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
      'AttributeController#attribute_definition' => 87.7,
      'BinaryRelease::update_binary_releases_via_json' => 122.54,
      'BranchPackage#find_packages_to_branch' => 239.64,
      'BranchPackage#create_branch_packages' => 210.91,
      'BranchPackage#determine_details_about_package_to_branch' => 196.38,
      'BranchPackage#check_for_update_project' => 110.23,
      'BsRequest#change_review_state' => 203.53,
      'BsRequest#sanitize!' => 165.33,
      'BsRequest#webui_actions' => 130.13,
      'BsRequest::new_from_xml' => 113.77,
      'BsRequestAction#check_action_permission!' => 232.82,
      'BsRequestAction#create_expand_package' => 291.31,
      'BsRequestAction#default_reviewers' => 141.02,
      'BsRequestAction#store_from_xml' => 88.01,
      'BsRequestActionMaintenanceIncident#merge_into_maintenance_incident' => 166.26,
      'BsRequestActionMaintenanceRelease#check_permissions!' => 91.4,
      'BsRequestActionSubmit#execute_accept' => 136.79,
      'BsRequestPermissionCheck#cmd_changestate_permissions' => 114.87,
      'BuildController#file' => 127.42,
      'BuildController#project_index' => 129.0,
      'ConfigurationsController#update' => 85.63,
      'IssueTrackersController#update' => 100.78,
      'MaintenanceIncident#initUpdateinfoId' => 140.32,
      'Owner::extract_maintainer' => 155.65,
      'PersonController#internal_register' => 112.01,
      'Project#update_one_repository_without_path' => 150.7,
      'PublicController#binary_packages' => 131.24,
      'Repository#cleanup_before_destroy' => 85.53,
      'RequestController#render_request_collection' => 92.82,
      'SearchController#find_attribute' => 97.33,
      'SourceController#project_command_copy' => 140.04,
      'SourceController#update_file' => 97.26,
      'SourceController#update_project_meta' => 127.52,
      'UserLdapStrategy::find_with_ldap' => 183.71,
      'UserLdapStrategy::render_grouplist_ldap' => 100.3,
      'Webui::DriverUpdateController#save' => 97.16,
      'Webui::PackageController#submit_request' => 149.9,
      'Webui::PatchinfoController#save' => 252.95,
      'Webui::ProjectController#check_devel_package_status' => 81.95, 
      'Webui::ProjectController#save_new' => 90,
      'Webui::ProjectController#save_targets' => 123.29,
      'Webui::SearchController#set_parameters' => 98.04,
      'Webui::WebuiHelper#flag_status' => 93.0,
      'WizardController#package_wizard' => 97.46
  }

  test 'code complexity' do
    require 'flog_cli'
    flog = Flog.new :continue => true
    dirs = %w(app/controllers app/views app/models app/mixins app/indices app/helpers app/jobs webui/app/controllers webui/app/models webui/app/helpers webui/app/mixins)
    files = FlogCLI.expand_dirs_to_files(*dirs)
    flog.flog(*files)

    black = BlackList.dup
    flog.calculate
    mismatches = []

    flog.each_by_score do |class_method, score, call_list|
      break if score < 80 # they are sorted. 80 means the function still fits on a standard screen
      next if class_method.end_with? '#none'
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
