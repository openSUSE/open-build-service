require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class GroupControllerTest < ActionController::IntegrationTest

  fixtures :all

  def test_list_groups
    ActionController::IntegrationTest::reset_auth
    get "/group"
    assert_response 401

    prepare_request_valid_user
    get "/group"
    assert_response :success
    assert_xml_tag :tag => 'directory', :child => {:tag => 'entry'}
    assert_xml_tag :tag => 'entry', :attributes => {:name => 'test_group'}
    assert_xml_tag :tag => 'entry', :attributes => {:name => 'test_group_b'}
  end

  def test_list_users_of_group
    ActionController::IntegrationTest::reset_auth
    get "/group/not_existing_group"
    assert_response 401

    prepare_request_valid_user
    get "/group/not_existing_group"
    assert_response 404
    get "/group/test_group"
    assert_response :success
    assert_xml_tag :tag => 'group', :child => {:tag => 'title'}, :content => "test_group"
    assert_xml_tag :tag => 'person', :attributes => {:userid => 'adrian'}
  end

  def test_groups_of_user
    ActionController::IntegrationTest::reset_auth
    get "/person/adrian/group"
    assert_response 401

    prepare_request_valid_user
    # old way, obsolete with OBS 3
    get "/person/adrian/group"
    assert_response :success
    assert_xml_tag :tag => 'directory', :child => {:tag => 'entry'}
    assert_xml_tag :tag => 'entry', :attributes => {:name => 'test_group'}
    assert_no_xml_tag :tag => 'entry', :attributes => {:name => 'test_group_b'}

    # new way, standard since OBS 2.3
    get "/group?login=adrian"
    assert_response :success
    assert_xml_tag :tag => 'directory', :child => {:tag => 'entry'}
    assert_xml_tag :tag => 'entry', :attributes => {:name => 'test_group'}
    assert_no_xml_tag :tag => 'entry', :attributes => {:name => 'test_group_b'}
  end

end
