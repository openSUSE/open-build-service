require File.expand_path(File.dirname(__FILE__) + '/..') + '/test_helper'

class BackendTests < ActionDispatch::IntegrationTest
  def test_validate_bsxml
    perlopts = "-I#{Rails.root}/../backend -I#{Rails.root}/../backend/build"
    dir = "#{Rails.root}/../../docs/api/api/"

    filtered_schemas = %w[about activity added_timestamp announcement announcements new_announcement architecture attrib attrib_type
                          attrib_namespace attribute_namespace_meta collection_objects_by_tag
                          collection_objects_with_tags_by_user configuration directory_filelist directory_view
                          group issue_tracker
                          packageresult projectresult projects redirect_stats status_message
                          latest_added latest_updated most_active_packages most_active_projects
                          status_messages tagcloud taglist tags updated_timestamp distribution distributions
                          productlist binary_released check required_checks status_report
                          staged_requests remove_staged_requests status_ok staging_project
                          staging_projects create_staging_workflow update_staging_workflow accept_staging_projects
                          excluded_requests create_excluded_requests delete_excluded_requests create_staging_projects backlog token tokenlist]

    Dir.entries(dir).each do |f|
      next unless /.*.xml\z/.match?(f)

      schema = f.gsub(/.xml$/, '')

      # map schema names
      if filtered_schemas.include?(schema)
        # no backend schema exists
        next
      elsif schema == 'aggregate'
        schema = 'aggregatelist'
      elsif schema == 'buildhistory'
        schema = 'buildhist'
      elsif schema == 'buildresult'
        schema = 'resultlist'
      elsif schema == 'directory'
        schema = 'dir'
      elsif schema == 'package'
        schema = 'pack'
      elsif schema == 'project'
        schema = 'proj'
      elsif schema == 'service'
        schema = 'services'
      elsif schema == 'status'
        schema = 'opstatus'
      elsif schema == 'user'
        schema = 'person'
      end

      r = system("cd #{ENV.fetch('OBS_BACKEND_TEMP', nil)}/config; " \
                 "exec perl #{perlopts} -mXML::Structured -mBSXML -mBSUtil -e \"use XML::Structured ':bytes'; BSUtil::readxml('#{dir}#{f}', \\$BSXML::#{schema}, 0);\" 2>&1")
      assert_equal true, r
    end
  end
end
