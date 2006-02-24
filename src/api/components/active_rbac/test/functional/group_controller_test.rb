require File.dirname(__FILE__) + '/../test_helper'
require 'group_controller'

# Re-raise errors caught by the controller.
class ActiveRbac::GroupController; def rescue_action(e) raise e end; end

class ActiveRbac::GroupControllerTest < Test::Unit::TestCase
  fixtures :roles, :users, :groups, :roles_users, :user_registrations, :groups_users, :groups_roles, :static_permissions, :roles_static_permissions

  def setup
    @controller = ActiveRbac::GroupController.new
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
  
  def test_should_create_new_group_on_create_post_with_valid_data_with_parent
    old_count = Group.count

    group = {
      'title' => 'My New Group',
      'roles' => [ @major_gods_role.id, @gods_role.id ],
      'parent' => @heroes_group.id
    }

    post :create, :group => group
  
    assert_response :redirect
    assert_redirected_to :action => 'show', :id => Group.count

    assert_equal(old_count, Group.count - 1)

    group = Group.find(:first, :order => 'id DESC')
    assert_kind_of Group, group
    assert_equal Group.find(@heroes_group.id), group.parent
    assert_equal 'My New Group', group.title
    assert_equal 2, group.roles.length
  end

  def test_should_create_new_group_on_create_post_with_valid_data_without_parent
    old_count = Group.count

    group = {
      'title' => 'My New Group',
      'roles' => [ @major_gods_role.id, @gods_role.id ],
      'parent' => ''
    }

    post :create, :group => group

    assert_equal(old_count, Group.count - 1)

    group = Group.find(:first, :order => 'id DESC')
    assert_kind_of Group, group
    assert_equal nil, group.parent
    assert_equal 'My New Group', group.title
    assert_equal 2, group.roles.length
  end

  def test_should_redirect_to_new_on_create_get
    get :create

    assert_response :redirect
    assert_redirected_to :action => 'list'
  end
  
  def test_should_display_form_and_errors_on_create_post_with_invalid_title
    invalid_chars = [ '†', '†', '¢', '∆', 'ƒ' ]
    
    for char in invalid_chars
      old_count = Group.count

      group = {
        'title' => 'Invalid Role Title: ' + char,
        'roles' => [ @major_gods_role.id, @gods_role.id ]
      }

      post :create, :group => group
      
      assert_response :success
      assert_template 'new'
      
      assert_tag :tag => 'li', :content => 'Title must not contain invalid characters'

      assert_equal(old_count, Group.count)
    end
  end
  
  def test_should_display_edit_form_on_edit_get_with_valid_group_id
    get :edit, :id => @heroes_group.id
    
    assert_response :success
    assert_template 'edit'
  end
  
  def test_should_redirect_to_list_on_edit_get_with_nonnumeric_group_id
    get :edit, :id => 'nonnumeric'

    assert_response :redirect
    assert_redirected_to :action => 'list'
  end

  def test_should_redirect_to_list_on_edit_get_with_invalid_group_id
    get :edit, :id => Group.count + 1

    assert_response :redirect
    assert_redirected_to :action => 'list'
  end

  def test_should_change_group_on_update_post_with_valid_data_parent_not_nil
    group = {
      'title' => 'New Role Title',
      'roles' => [ @major_gods_role.id, @gods_role.id ],
      'parent' => @heroes_group.id
    }

    post :update, :id => @greek_kings_group.id, :group => group

    assert_response :redirect
    assert_redirected_to :action => 'show', :id => @greek_kings_group.id

    group = Group.find(@greek_kings_group.id)
    assert_equal 'New Role Title', group.title
    assert_equal @heroes_group, group.parent
    assert_equal 2, group.roles.length
    assert_equal [ @major_gods_role, @gods_role ].sort {|a,b| a.id <=> b.id}, group.roles.sort {|a,b| a.id <=> b.id}
  end

  def test_should_change_group_on_update_post_with_valid_data_parent_to_nil
    group = {
      'title' => 'New Role Title',
      'roles' => [ @major_gods_role.id, @gods_role.id ],
      'parent' => ''
    }

    post :update, :id => @greek_kings_group.id, :group => group

    assert_response :redirect
    assert_redirected_to :action => 'show', :id => @greek_kings_group.id
    
    assert_equal flash[:notice], 'Group has been updated successfully.'

    group = Group.find(@greek_kings_group.id)
    assert_equal 'New Role Title', group.title
    assert_equal nil, group.parent
    assert_equal 2, group.roles.length
    assert_equal [ @major_gods_role, @gods_role ].sort {|a,b| a.id <=> b.id}, group.roles.sort {|a,b| a.id <=> b.id}
  end

  def test_should_redirect_to_list_on_update_post_with_nonnumeric_group_id
    post :update, :id => 'nonnumeric'

    assert_response :redirect
    assert_redirected_to :action => 'list'
  end

  def test_should_redirect_to_list_on_update_post_with_invalid_group_id
    post :update, :id => Group.count + 1

    assert_response :redirect
    assert_redirected_to :action => 'list'
  end

  def test_should_display_form_and_errors_on_update_post_with_invalid_title
    invalid_chars = [ '†', '¢', '∆', 'ƒ' ]

    for char in invalid_chars
      group = {
        'title' => 'Invalid Role Title: ' + char,
        'roles' => [ @major_gods_role.id, @gods_role.id ]
      }

      post :update, :id => @heroes_group.id, :group => group
      
      assert_response :success
      assert_template 'edit'

      assert_tag :tag => 'li', :content => 'Title must not contain invalid characters'
      
      assert_equal @heroes_group.title, Group.find(@heroes_group.id).title
    end
  end
  
  def test_should_display_confirmation_form_on_delete_get_with_valid_group_id
    get :delete, :id => @heroes_group.id
    
    assert_response :success
    assert_template 'delete'
  end
  
  def test_should_redirect_to_delete_on_destroy_get
    old_count = Group.count

    get :destroy, :id => @heroes_group.id, :yes => 'Yes'

    assert_response :redirect
    assert_redirected_to :action => 'list'
    
    assert_nothing_raised { Group.find(@heroes_group.id) }
    assert_equal old_count, Group.count
  end

  def test_should_redirect_to_list_on_destroy_post_with_invalid_group_id
    old_count = Group.count
    
    post :destroy, :id => (Group.count + 1), :yes => 'Yes'

    assert_response :redirect
    assert_redirected_to :action => 'list'
    
    assert_equal old_count, Group.count
  end

  def test_should_redirect_to_list_on_destroy_post_with_nonumerical_group_id
    old_count = Group.count

    post :destroy, :id => 'nonnumeric', :yes => 'Yes'

    assert_response :redirect
    assert_redirected_to :action => 'list'

    assert_equal old_count, Group.count
  end

  def test_should_destroy_group_on_destroy_post_with_answer_yes_and_valid_group_id
    post :destroy, :id => @heroes_group.id, :yes => 'Yes'

    assert_response :redirect
    assert_redirected_to :action => 'list'

    assert_raise(ActiveRecord::RecordNotFound) { Group.find(@heroes_group.id) }
  end

  def test_should_redirect_to_list_on_destroy_post_with_answer_no_and_valid_group_id
    old_count = Group.count

    post :destroy, :id => @heroes_group.id, :no => 'No'

    assert_response :redirect
    assert_redirected_to :action => 'show', :id => @heroes_group.id.to_s

    assert_equal old_count, Group.count
  end
end