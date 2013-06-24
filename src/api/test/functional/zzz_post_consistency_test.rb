require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_consistency_helper"

class ZZZPostConsistency < ActionDispatch::IntegrationTest 
  fixtures :all
  
  def test_resubmit_fixtures
    resubmit_all_fixtures
  end

  def test_check_maintenance_project
    prepare_request_with_user "king", "sunflower"
    get "/source/My:Maintenance/_meta"
    assert_response :success
    
    get "/search/project", :match => '[maintenance/maintains/@project="BaseDistro2.0:LinkedUpdateProject"]'
    assert_response :success
    assert_tag :tag => 'collection', :children => { :count => 1 }
    assert_tag :tag => 'project', :attributes => { :name => "My:Maintenance" }
  end
end

