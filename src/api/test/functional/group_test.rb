require File.dirname(__FILE__) + '/../test_helper'

class GrouopControllerTest < ActionController::IntegrationTest 

  fixtures :all
 
  def test_list_groups
    prepare_request_valid_user
    get "/group"
    assert_response :success   
    assert_tag :tag => 'directory', :child => {:tag => 'entry' }
    assert_tag :tag => 'entry', :attributes => {:name => 'test_group' }
  end

  def test_list_users_of_group
    prepare_request_valid_user
    get "/group/test_group"
    assert_response :success   
    assert_tag :tag => 'directory', :child => {:tag => 'entry' }
    assert_tag :tag => 'entry', :attributes => {:name => 'adrian' }
  end

  def test_groups_of_user
    prepare_request_valid_user
    get "/person/adrian/group"
    assert_response :success
    assert_tag :tag => 'directory', :child => {:tag => 'entry' }
    assert_tag :tag => 'entry', :attributes => {:name => 'test_group' }
  end

end
