require File.expand_path(File.dirname(__FILE__) + '/..') + '/test_helper'
require 'find'
require 'tempfile'

RAILS_BASE_DIRS = %w(app db config lib test).map { |dir| Rails.root.join(dir) }

class CodeQualityTest < ActiveSupport::TestCase
  def setup
    @ruby_files = []
    RAILS_BASE_DIRS.each do |base_dir|
      Find.find(base_dir.to_s) do |path|
        @ruby_files << path if FileTest.file?(path) && path.end_with?('.rb') && path !~ /\/lib\/templates\//
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
    IO.popen("ruby.ruby2.4 -cv - 2>&1 > /dev/null | grep '^-' > #{tmpfile.path}", 'w') do |io|
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
      IO.popen("ruby.ruby2.4 -cv #{failedfile} 2>&1 > /dev/null | grep #{Rails.root}") do |io|
        line = io.read
        unless line.empty?
          assert(false, "ruby -cv gave output\n#{line}")
        end
      end
    end
  end

  # our current exceptions
  BLACK_LIST = {
      'AttributeController#attribute_definition'                                => 92.09,
      'BinaryRelease::update_binary_releases_via_json'                          => 128.58,
      'BranchPackage#find_packages_to_branch'                                   => 226.72,
      'BranchPackage#create_branch_packages'                                    => 227.35,
      'BranchPackage#check_for_update_project'                                  => 103.23,
      'BranchPackage#determine_details_about_package_to_branch'                 => 101.48,
      'BranchPackage#lookup_incident_pkg'                                       => 83.09,
      'BranchPackage#extend_packages_to_link'                                   => 80.23,
      'BsRequest#change_review_state'                                           => 212.16,
      'BsRequest#apply_default_reviewers'                                       => 129.52,
      'BsRequest#webui_actions'                                                 => 130.13,
      'BsRequest::new_from_xml'                                                 => 113.77,
      'BsRequestAction#check_action_permission!'                                => 113.85,
      'BsRequestAction#check_action_permission_target!'                         => 89.68,
      'BsRequestAction#create_expand_package'                                   => 459.98,
      'BsRequestAction#default_reviewers'                                       => 137.71,
      'BsRequestAction#store_from_xml'                                          => 88.01,
      'BsRequestActionMaintenanceIncident#_merge_pkg_into_maintenance_incident' => 153.15,
      'BsRequestActionSubmit#execute_accept'                                    => 126.42,
      'BsRequestPermissionCheck#cmd_changestate_permissions'                    => 117.09,
      'RequestSourceDiff::ActionSourceDiffer#diff_for_source'                   => 94.62,
      'BuildController#file'                                                    => 127.42,
      'BuildController#project_index'                                           => 126.35,
      'ConfigurationsController#update'                                         => 82.1,
      'IssueTrackersController#update'                                          => 100.78,
      'MaintenanceHelper#instantiate_container'                                 => 163.57,
      'PersonController#internal_register'                                      => 112.01,
      'Package#find_changed_issues'                                             => 93.74,
      'Package#close_requests'                                                  => 84.82,
      'Flag#compute_status'                                                     => 145.55,
      'PublicController#binary_packages'                                        => 126.16,
      'RequestController#render_request_collection'                             => 85.91,
      'SearchController#find_attribute'                                         => 97.33,
      'SearchController#search'                                                 => 81.15,
      'SourceController#project_command_copy'                                   => 140.04,
      'SourceController#update_project_meta'                                    => 98.09,
      'UserLdapStrategy::find_with_ldap'                                        => 122.14,
      'User::find_with_credentials'                                             => 101.42,
      'Webui::WebuiController#check_user'                                       => 80.99,
      'UserLdapStrategy::render_grouplist_ldap'                                 => 98.25,
      'Webui::PackageController#branch'                                         => 124.26,
      'Webui::PackageController#submit_request'                                 => 110.76,
      'Webui::PackageController#dependency'                                     => 83.57,
      'Webui::PackageController#update_build_log'                               => 81.73,
      'Webui::PatchinfoController#save'                                         => 256.25,
      'Webui::RequestController#show'                                           => 91.96,
      'Webui::SearchController#set_parameters'                                  => 98.04,
      'WizardController#package_wizard'                                         => 97.46,
      'Project::UpdateFromXmlCommand#run'                                       => 90.85
  }

  test 'code complexity' do
    require 'flog_cli'
    flog = Flog.new continue: true
    dirs = %w(app/controllers app/views app/models
              app/mixins app/indices app/helpers
              app/jobs webui/app/controllers webui/app/models
              webui/app/helpers webui/app/mixins)
    files = PathExpander.new([], "**/*.rb").expand_dirs_to_files(*dirs)
    flog.flog(*files)

    black = BLACK_LIST.dup
    flog.calculate
    mismatches = []

    flog.each_by_score do |class_method, score, _|
      break if score < 80 # they are sorted. 80 means the function still fits on a standard screen
      next if class_method.end_with? '#none'
      score = Integer(score * 100)
      score /= Float(100)

      oldscore = black.delete class_method
      if oldscore.nil?
        mismatches << "'#{class_method}' => #{score}, "
        next
      end
      # don't want to be too strict here
      next if (oldscore - score).abs < 2
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
