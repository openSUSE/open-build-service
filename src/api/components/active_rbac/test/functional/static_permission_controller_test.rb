require File.dirname(__FILE__) + '/../test_helper'
require 'static_permission_controller'

# Re-raise errors caught by the controller.
class ActiveRbac::StaticPermissionController; def rescue_action(e) raise e end; end

class ActiveRbac::StaticPermissionControllerTest < Test::Unit::TestCase
  fixtures :roles, :users, :groups, :roles_users, :user_registrations, :groups_users, :groups_roles, :static_permissions, :roles_static_permissions

  def setup
    @controller = ActiveRbac::StaticPermissionController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_delete
    get :delete, :id => @sit_on_throne_permission.id
    
    assert_response :success
    assert_template 'delete'
  end

  def test_index
    get :index
    assert_response :redirect
    assert_redirected_to :action => 'list'
  end

  def test_list
    get :list

    assert_response :success
    assert_template 'list'

    assert_not_nil assigns(:permissions)
  end

  def test_show
    get :show, :id => 1

    assert_response :success
    assert_template 'show'

    assert_not_nil assigns(:permission)
    assert assigns(:permission).valid?
  end

  def test_new
    get :new

    assert_response :success
    assert_template 'new'

    assert_not_nil assigns(:permission)
  end

  def test_create
    num_permissions = StaticPermission.count

    post :create, :permission => { 'title' => 'Nice Permission' }

    assert_response :redirect
    assert_redirected_to :action => 'show', :id => num_permissions + 1

    assert_equal num_permissions + 1, StaticPermission.count
  end

  def test_edit
    get :edit, :id => 1

    assert_response :success
    assert_template 'edit'

    assert_not_nil assigns(:permission)
    assert assigns(:permission).valid?
  end

  def test_update
    post :update, :id => 1
    assert_response :redirect
    assert_redirected_to :action => 'show', :id => 1
  end

  def test_destroy
    assert_not_nil StaticPermission.find(1)

    post :destroy, :id => 1, :yes => 'Yes'
    assert_response :redirect
    assert_redirected_to :action => 'list'

    assert_raise(ActiveRecord::RecordNotFound) {
      StaticPermission.find(1)
    }
  end
end
