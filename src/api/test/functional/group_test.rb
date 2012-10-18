require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class GroupControllerTest < ActionController::IntegrationTest

  fixtures :all

  def test_list_groups
    reset_auth
    get "/group"
    assert_response 401

    prepare_request_valid_user
    get "/group"
    assert_response :success
    assert_xml_tag :tag => 'directory', :child => {:tag => 'entry'}
    assert_xml_tag :tag => 'entry', :attributes => {:name => 'test_group'}
    assert_xml_tag :tag => 'entry', :attributes => {:name => 'test_group_b'}

    get "/group?login=adrian"
    assert_response :success
    assert_xml_tag :tag => 'entry', :attributes => {:name => 'test_group'}

    get "/group?prefix=test"
    assert_response :success
    assert_xml_tag :tag => 'entry', :attributes => {:name => 'test_group'}
  end

  def test_get_group
    reset_auth
    get "/group/test_group"
    assert_response 401

    prepare_request_valid_user
    get "/group/test_group"
    assert_response :success
    assert_xml_tag :parent => { :tag => 'group' }, :tag => 'title', :content => "test_group"
    assert_xml_tag :tag => 'person', :attributes => {:userid => 'adrian'}

    get "/group/does_not_exist"
    assert_response 404
  end

  def test_create_modify_and_delete_group
    xml = "<group><title>new_group</title></group>"
    reset_auth
    put "/group/new_group", xml
    assert_response 401

    prepare_request_valid_user
    put "/group/new_group", xml
    assert_response 403
    delete "/group/new_group"
    assert_response 403

    prepare_request_with_user "king", "sunflower"
    get "/group/new_group"
    assert_response 404
    delete "/group/new_group"
    assert_response 404
    put "/group/new_group", xml
    assert_response :success

    # add a user
    xml2 = "<group><title>new_group</title> <person userid='fred' /> </group>"
    put "/group/new_group", xml2
    assert_response :success
    get "/group/new_group"
    assert_response :success
    assert_xml_tag :tag => 'person', :attributes => {:userid => 'fred'}

    # remove user
    put "/group/new_group", xml
    assert_response :success
    get "/group/new_group"
    assert_response :success
    assert_no_xml_tag :tag => 'person', :attributes => {:userid => 'fred'}

    # remove group
    delete "/group/new_group"
    assert_response :success
    get "/group/new_group"
    assert_response 404
  end

  def test_list_users_of_group
    reset_auth
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
    reset_auth
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
