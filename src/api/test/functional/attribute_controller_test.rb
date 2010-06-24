require File.dirname(__FILE__) + '/../test_helper'
require 'attribute_controller'

# Re-raise errors caught by the controller.
class AttributeController; def rescue_action(e) raise e end; end

class AttributeControllerTest < ActionController::IntegrationTest 
  
  fixtures :db_projects, :db_packages, :users, :project_user_role_relationships, :roles
  fixtures :static_permissions, :roles_static_permissions, :attrib_types
  fixtures :attrib_namespaces, :attribs, :attrib_namespace_modifiable_bies

  def setup
    @controller = AttributeController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
 
    @tom = User.find_by_login("tom")
    @tscholz = User.find_by_login("tscholz")
  end

  def test_index
    ActionController::IntegrationTest::reset_auth
    get "/attribute/"
    assert_response 401

    prepare_request_with_user "tscholz", "asdfasdf" 
    get "/attribute/"
    assert_response :success

    # only one entry ATM - will have to be adopted, lists namespaces
    count = 1
    assert_tag :tag => 'directory', :attributes => { :count => count }
    assert_tag :children => { :count => count }
    assert_tag :child => { :tag => 'entry', :attributes => { :name => "NSTEST" } }
  end

  def test_namespace_index
    prepare_request_with_user "tscholz", "asdfasdf"

    get "/attribute/Redhat"
    assert_response 400

    get "/attribute/NSTEST"
    assert_response :success
    count = 2
    assert_tag :tag => 'directory', :attributes => { :count => count }
    assert_tag :children => { :count => count }
    assert_tag :child => { :tag => 'entry', :attributes => { :name => "Maintained" } }
  end

  def test_namespace_meta
    prepare_request_with_user "tscholz", "asdfasdf"
    get "/attribute/NSTEST/_meta"
    assert_response :success
    assert_tag :tag => 'namespace', :attributes => { :name => "NSTEST" }
    assert_tag :children => { :count => 1 }
    assert_tag :child => { :tag => 'modifiable_by', :attributes => { :user => "king" } }
  end

end

