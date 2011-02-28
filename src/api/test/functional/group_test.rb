require File.dirname(__FILE__) + '/../test_helper'

class GroupControllerTest < ActionController::IntegrationTest

  fixtures :all

  def test_list_groups
    ActionController::IntegrationTest::reset_auth
    get "/group"
    assert_response 401

    prepare_request_valid_user
    get "/group"
    assert_response :success
    assert_tag :tag => 'directory', :child => {:tag => 'entry'}
    assert_tag :tag => 'entry', :attributes => {:name => 'test_group'}
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
    assert_tag :tag => 'directory', :child => {:tag => 'entry'}
    assert_tag :tag => 'entry', :attributes => {:name => 'adrian'}

    get "/group/show/test_group"
    assert_response :success
    assert_tag :tag => 'group', :child => {:tag => 'title', :content => 'test_group'}
    grp = @response.body

    put "/group/show/test_group", "<group><title>new</title></group>"
    assert_response 403

    # group rename
    prepare_request_with_user "king", "sunflower"
    put "/group/show/test_group", "<group><title>new</title></group>"
    assert_response :success
    get "/group/show/test_group"
    assert_response 404
    get "/group/show/new"
    assert_response :success
    assert_tag :tag => 'group', :child => {:tag => 'title', :content => 'new'}

    # rename it back
    put "/group/show/new", grp
    assert_response :success
  end

  def test_users_of_group_the_other_way
    ActionController::IntegrationTest::reset_auth
    get "/group/users/test_group"
    assert_response 401

    prepare_request_valid_user
    get "/group/users/test_group"
    assert_response :success
    assert_tag :tag => 'directory', :child => {:tag => 'entry'}
    assert_tag :tag => 'entry', :attributes => {:name => 'adrian'}

    get "/group/users/not_existing_group"
    assert_response 404
  end

  def test_groups_of_user
    ActionController::IntegrationTest::reset_auth
    get "/person/adrian/group"
    assert_response 401

    prepare_request_valid_user
    get "/person/adrian/group"
    assert_response :success
    assert_tag :tag => 'directory', :child => {:tag => 'entry'}
    assert_tag :tag => 'entry', :attributes => {:name => 'test_group'}
  end

end
