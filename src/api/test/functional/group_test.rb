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
