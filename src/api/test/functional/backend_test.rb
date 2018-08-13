require File.expand_path(File.dirname(__FILE__) + '/..') + '/test_helper'

class BackendTests < ActionDispatch::IntegrationTest
  def test_validate_bsxml
    perlopts = "-I#{Rails.root}/../backend -I#{Rails.root}/../backend/build"
    dir = "#{Rails.root}/../../docs/api/api/"

    Dir.entries(dir).each do |f|
      next unless f =~ /.*.xml\z/

      schema = f.gsub(/.xml$/, '')

      # map schema names
      if ['about', 'activity', 'added_timestamp', 'architecture', 'attrib', 'attrib_type',
          'attrib_namespace', 'attribute_namespace_meta', 'collection_objects_by_tag',
          'collection_objects_with_tags_by_user', 'configuration', 'directory_view', 'download_counter',
          'download_counter_summary', 'download_stats', 'group', 'highest_rated', 'issue_tracker',
          'latest_added', 'latest_updated', 'message', 'messages', 'most_active', 'newest_stats',
          'packageresult', 'projectresult', 'projects', 'rating', 'redirect_stats', 'status_message',
          'status_messages', 'tagcloud', 'taglist', 'tags', 'updated_timestamp', 'distributions',
          'productlist', 'binary_released'].include?(schema)
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

      # rubocop:disable Metrics/LineLength
      r = system("cd #{ENV['OBS_BACKEND_TEMP']}/config; exec perl #{perlopts} -mXML::Structured -mBSXML -mBSUtil -e \"use XML::Structured ':bytes'; BSUtil::readxml('#{dir}#{f}', \\\$BSXML::#{schema}, 0);\" 2>&1")
      # rubocop:enable Metrics/LineLength
      assert_equal true, r
    end
  end
end
