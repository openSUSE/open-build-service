require File.dirname(__FILE__) + '/../test_helper'
require 'role_controller'

# Re-raise errors caught by the controller.
class ActiveRbac::RoleController; def rescue_action(e) raise e end; end

class ActiveRbac::RoleControllerTest < Test::Unit::TestCase
  fixtures :roles, :users, :groups, :roles_users, :user_registrations, :groups_users, :groups_roles, :static_permissions, :roles_static_permissions

  def setup
    @controller = ActiveRbac::RoleController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_should_redirect_to_list_on_index_get
    get :index
    assert_response :redirect
    assert_redirected_to :action => 'list'
  end

  def test_should_display_list_on_list_get
    get :list

    assert_response :success
    assert_template 'list'
  end

  def test_should_display_new_form_on_new_get
    get :new

    assert_response :success
    assert_template 'new'
  end

  def test_should_create_new_role_on_create_post_with_valid_data_with_parent
    old_count = Role.count

    role = {
      'title' => 'My New Role',
      'static_permissions' => [ @slay_monsters_permission.id, @sit_on_throne_permission.id ],
      'parent' => @greek_heroes_role.id
    }

    post :create, :role => role

    assert_equal(old_count, Role.count - 1)

    role = Role.find(Role.count)
    assert_kind_of Role, role
    assert_equal Role.find(@greek_heroes_role.id), role.parent
    assert_equal 'My New Role', role.title
    assert_equal 2, role.static_permissions.length
  end

  def test_should_create_new_role_on_create_post_with_valid_data_without_parent
    old_count = Role.count

    role = {
      'title' => 'My New Role',
      'static_permissions' => [ @slay_monsters_permission.id, @sit_on_throne_permission.id ],
      'parent' => ''
    }
    
    post :create, :role => role
    assert_redirected_to :action => 'show', :id => Role.find(:first, :order => 'id DESC').id

    assert_equal(old_count, Role.count - 1)

    role = Role.find(:first, :order => 'id DESC')
    assert_kind_of Role, role
    assert_equal nil, role.parent
    assert_equal 'My New Role', role.title
    assert_equal 2, role.static_permissions.length
  end

  def test_should_redirect_to_new_on_create_get
    get :create

    assert_response :redirect
    assert_redirected_to :action => 'list'
  end

  def test_should_display_form_and_errors_on_create_post_with_invalid_title
    invalid_chars = [ '†', '†', '¢', '∆', 'ƒ' ]

    for char in invalid_chars
      old_count = Role.count

      role = {
        'title' => 'Invalid Role Title: ' + char,
        'static_permissions' => [ @slay_monsters_permission.id, @sit_on_throne_permission.id ],
      }

      post :create, :role => role

      assert_response :success
      assert_template 'new'

      assert_tag :tag => 'li', :content => 'Title must not contain invalid characters'

      assert_equal(old_count, Role.count)
    end
  end

  def test_should_display_edit_form_on_edit_get_with_valid_role_id
    get :edit, :id => @greek_kings_role.id

    assert_response :success
    assert_template 'edit'
  end

  def test_should_redirect_to_list_on_edit_get_with_nonnumeric_role_id
    get :edit, :id => 'nonnumeric'

    assert_response :redirect
    assert_redirected_to :action => 'list'
  end

  def test_should_redirect_to_list_on_edit_get_with_invalid_role_id
    get :edit, :id => Role.count + 1

    assert_response :redirect
    assert_redirected_to :action => 'list'
  end

  def test_should_change_role_on_update_post_with_valid_data_parent_not_nil
    role = {
      'title' => 'New Role Title',
      'static_permissions' => [ @slay_monsters_permission.id, @sit_on_throne_permission.id ],
      'parent' => @greek_heroes_role.id
    }

    post :update, :id => @greek_kings_role.id, :role => role

    assert_response :redirect
    assert_redirected_to :action => 'show', :id => @greek_kings_role.id

    role = Role.find(@greek_kings_role.id)
    assert_equal 'New Role Title', role.title
    assert_equal @greek_heroes_role, role.parent
    assert_equal 2, role.static_permissions.length
    assert_equal [ @sit_on_throne_permission, @slay_monsters_permission ].sort {|a,b| a.id <=> b.id}, role.static_permissions.sort {|a,b| a.id <=> b.id}
  end

  def test_should_change_role_on_update_post_with_valid_data_parent_to_nil
    role = {
      'title' => 'New Role Title',
      'static_permissions' => [ @slay_monsters_permission.id, @sit_on_throne_permission.id ],
      'parent' => ''
    }

    post :update, :id => @greek_kings_role.id, :role => role

    assert_response :redirect
    assert_redirected_to :action => 'show', :id => @greek_kings_role.id

    assert_equal flash[:notice], 'Role has been updated successfully.'

    role = Role.find(@greek_kings_role.id)
    assert_equal 'New Role Title', role.title
    assert_nil role.parent
    assert_equal 2, role.static_permissions.length
    assert_equal [ @sit_on_throne_permission, @slay_monsters_permission ].sort {|a,b| a.id <=> b.id}, role.static_permissions.sort {|a,b| a.id <=> b.id}
  end

  def test_should_redirect_to_list_on_update_post_with_nonnumeric_role_id
    post :update, :id => 'nonnumeric'

    assert_response :redirect
    assert_redirected_to :action => 'list'
  end

  def test_should_redirect_to_list_on_update_post_with_invalid_role_id
    post :update, :id => Role.count + 1

    assert_response :redirect
    assert_redirected_to :action => 'list'
  end

  def test_should_display_form_and_errors_on_update_post_with_invalid_title
    invalid_chars = [ '†', '¢', '∆', 'ƒ' ]

    for char in invalid_chars
      role = {
        'title' => 'Invalid Role Title: ' + char,
        'static_permissions' => [ @slay_monsters_permission.id, @sit_on_throne_permission.id ],
      }

      post :update, :id => @greek_kings_role.id, :role => role

      assert_response :success
      assert_template 'edit'

      assert_tag :tag => 'li', :content => 'Title must not contain invalid characters'

      assert_equal @greek_kings_role.title, Role.find(@greek_kings_role.id).title
    end
  end

  def test_should_display_confirmation_form_on_delete_get_with_valid_role_id
    get :delete, :id => @greek_kings_role.id

    assert_response :success
    assert_template 'delete'
  end

  def test_should_redirect_to_list_on_destroy_get
    old_count = Role.count

    get :destroy, :id => @greek_kings_role.id, :yes => 'Yes'

    assert_response :redirect
    assert_redirected_to :action => 'list'

    assert_nothing_raised { Role.find(@greek_kings_role.id) }
    assert_equal old_count, Role.count
  end

  def test_should_redirect_to_list_on_destroy_post_with_invalid_role_id
    old_count = Role.count

    post :destroy, :id => (Role.count + 1), :yes => 'Yes'

    assert_response :redirect
    assert_redirected_to :action => 'list'

    assert_equal old_count, Role.count
  end

  def test_should_redirect_to_list_on_destroy_post_with_nonumerical_role_id
    old_count = Role.count

    post :destroy, :id => 'nonnumeric', :yes => 'Yes'

    assert_response :redirect
    assert_redirected_to :action => 'list'

    assert_equal old_count, Role.count
  end

  def test_should_destroy_role_on_destroy_post_with_answer_yes_and_valid_role_id
    post :destroy, :id => @greek_kings_role.id, :yes => 'Yes'

    assert_response :redirect
    assert_redirected_to :action => 'list'

    assert_raise(ActiveRecord::RecordNotFound) { Role.find(@greek_kings_role.id) }
  end

  def test_should_redirect_to_list_on_destroy_post_with_answer_no_and_valid_role_id
    old_count = Role.count

    post :destroy, :id => @greek_kings_role.id, :no => 'No'

    assert_response :redirect
    assert_redirected_to :action => 'show', :id => @greek_kings_role.id.to_s

    assert_kind_of Role, Role.find(@greek_kings_role.id)
    assert_equal old_count, Role.count
  end
end
