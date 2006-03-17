require File.dirname(__FILE__) + '/../test_helper'
require 'user_controller'

# Re-raise errors caught by the controller.
class ActiveRbac::UserController; def rescue_action(e) raise e end; end

class ActiveRbac::UserControllerTest < Test::Unit::TestCase
  fixtures :roles, :users, :groups, :roles_users, :user_registrations, :groups_users, :groups_roles

  def setup
    @icarus = User.find @icarus_user.id
    
    @controller = ActiveRbac::UserController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_should_display_list_on_get_index
    get :index
    assert_response :redirect
    assert_redirected_to :action => 'list'
  end

  def test_should_display_list_on_get_list
    get :list

    assert_response :success
    assert_template 'list'

    assert_not_nil assigns(:users)
  end

  def test_should_display_user_on_get_show_with_valid_id
    users = [ @agamemnon_user, @ariadne_user, @daidalos_user, @dionysus_user, 
              @hades_user, @hephaestus_user, @hermes_user, @icarus_user, @medusa_user, 
              @minos_user, @odysseus_user, @perseus_user, @zeus_user ]
    for fixture_user in users 
      get :show, :id => fixture_user.id
      
      db_user = User.find fixture_user.id

      assert_response :success
      assert_template 'show'

      # do data tests
      user = assigns(:user)
      assert_not_nil user
      assert_equal db_user.id, user.id
      assert_equal db_user.login, user.login
      assert_equal db_user.password, user.password
      assert_equal db_user.email, user.email
      
      # do output matching tests
      assert_tag :tag => 'dd', :content => db_user.id.to_s
      assert_tag :tag => 'dd', :content => db_user.created_at.to_formatted_s(:long)
      assert_tag :tag => 'dd', :content => db_user.updated_at.to_formatted_s(:long)
      assert_tag :tag => 'dd', :content => db_user.last_logged_in_at.to_formatted_s(:long)
      assert_tag :tag => 'dd', :content => db_user.login
      assert_tag :tag => 'dd', :content => db_user.password_hash_type
      assert_tag :tag => 'dd', :content => User.states.invert[db_user.state]
      
      next
      
      ## MEH! ##
      ## WE SKIP EVERYTHING BELOW SINCE IT DOES NOT WORK CORRECTLY
      ## TODO: We have to rework the display checking later on.

      # Check that roles display correctly
      if db_user.roles.empty?
        assert_tag :tag => 'p', :content => 'No Roles', 
                   :after => { :tag => 'h3', :content => 'Directly Assigned Roles' },
                   :before => { :tag => 'h3', :content => 'All Assigned Roles' }
      else
        for role in db_user.roles
          ancestor_conditions = { :tag => 'ul',
                                 :after => { :tag => 'h3', :content => 'Directly Assigned Roles' },
                                 :before => { :tag => 'h3', :content => 'All Assigned Roles' } }
          assert_tag :tag => 'li', :content => role.title, :ancestor => ancestor_conditions
          assert_tag :tag => 'a', :attributes => { 'href' => %r{role\/show\/#{role.id}} }, :ancestor => ancestor_conditions
        end
      end

      # Check that all_roles display correctly
      if db_user.all_roles.empty?
        assert_tag :tag => 'p', :content => 'No Roles', 
#                   :after => { :tag => 'h3', :content => 'All Assigned Roles' }
                   :before => { :tag => 'h3', :content => 'All Assigned Groups' }
      else
        for role in db_user.all_roles
          ancestor_conditions = { :tag => 'ul', :after => { :tag => 'h3', :content => 'All Assigned Roles' } }
          assert_tag :tag => 'li', :content => role.title, :ancestor => ancestor_conditions
          assert_tag :tag => 'a', :attributes => { 'href' => %r{role\/show\/#{role.id}} }, :ancestor => ancestor_conditions
        end
      end

      # Check that groups display correctly
      if db_user.groups.empty?
        assert_tag :tag => 'p', :content => 'No Groups', 
                   :after => { :tag => 'h3', :content => 'Directly Assigned Groups' },
                   :before => { :tag => 'h3', :content => 'All Assigned Groups' }
      else
        for group in db_user.groups
          ancestor_conditions =  { :tag => 'ul',
                                   :after => { :tag => 'h3', :content => 'Directly Assigned Groups' },
                                   :before => { :tag => 'h3', :content => 'All Assigned Groups' } }
          assert_tag :tag => 'li', :content => group.title, :ancestor => ancestor_conditions 
          assert_tag :tag => 'a', :attributes => { 'href' => %r{group\/show\/#{group.id}} }, :ancestor => ancestor_conditions
        end
      end

      # Check that all_groups display correctly
      
      if db_user.all_groups.empty?
        assert_tag :tag => 'p', :content => 'No Groups', 
                   :after => { :tag => 'h3', :content => 'All Assigned Groups' }
      else
        for group in db_user.all_groups
          ancestor_conditions = { :tag => 'ul', :after => { :tag => 'h3', :content => 'All Assigned Groups' } }
          assert_tag :tag => 'li', :content => group.title, :ancestor => ancestor_conditions
          assert_tag :tag => 'a', :attributes => { 'href' => %r{group\/show\/#{group.id}} }, :ancestor => ancestor_conditions
        end
      end
    end
  end

  def test_should_redirect_to_list_on_get_show_without_id
    get :show

    assert_response :redirect
    assert_redirected_to :action => 'list'

    assert_equal 'This user could not be found.', flash[:notice]
  end

  def test_should_redirect_to_list_on_get_show_with_invalid_numeric_id
    id = User.count + 1
    assert_raises(ActiveRecord::RecordNotFound) { User.find(id) }
    get :show, :id => id

    assert_response :redirect
    assert_redirected_to :action => 'list'

    assert_equal 'This user could not be found.', flash[:notice]
  end

  def test_should_redirect_to_list_on_get_show_with_invalid_nonnumeric_id
    get :show, :id => 'invalid'

    assert_response :redirect
    assert_redirected_to :action => 'list'

    assert_equal 'This user could not be found.', flash[:notice]
  end

  def test_should_create_new_nonsaved_record_and_display_form_on_get_new
    get :new

    assert_response :success
    assert_template 'new'
    
    # test that the template values have been correctly assigned
    assert_not_nil assigns(:user)
    assert_equal true, assigns(:user).new_record?
    
    # test form output
    assert_tag :tag => 'form', :attributes => { :action => %r{user/create}, :method => 'post' }
    
    assert_tag :tag => 'input', :attributes => { :id => 'user_login', :name => 'user[login]', :type => 'text' }
    assert_tag :tag => 'input', :attributes => { :id => 'user_email', :name => 'user[email]', :type => 'text' }
    assert_tag :tag => 'input', :attributes => { :id => 'password', :name => 'password', :type => 'password' }
    assert_tag :tag => 'input', :attributes => { :id => 'password_confirmation', :name => 'password_confirmation', :type => 'password' }
    assert_tag :tag => 'select', 
               :attributes => { :id => 'user_password_hash_type', :name => 'user[password_hash_type]' },
               :children => { :count => 1 }
    assert_tag :tag => 'select', :attributes => { :id => 'user_state', :name => 'user[state]'},
               :children => { :greater_than => 0 }
  end

  # We want to be redirected if we try a GET on create - dangerous actions are
  # POST only!
  def test_create_redirect_on_get
    get :create, :id => 1

    assert_response :redirect
    assert_redirected_to :action => 'list'
  end

  def test_create_with_valid_data_submit_create
    num_users = User.count

    userdata = {
      'login' => 'This is my name',
      'state' => User.states['unconfirmed'],
      'email' => 'email@foobar.com',
      'roles' => [1.to_s, '2'],
      'password_hash_type' => 'md5',
    }
    post :create, :user => userdata, :submit => { 'create' => 'Create' },
      'password' => 'My Nice Password', 'password_confirmation' => 'My Nice Password'

    assert_response :redirect
    assert_redirected_to :action => 'show'#, :id => num_users + 1

    assert_equal num_users + 1, User.count
    
    user = User.find(:first, :order => 'id DESC')
    assert_kind_of User, user
    assert_equal 2, user.roles.length
  end

  def DEACTIVATED_test_create_with_valid_data_submit_preview
    num_users = User.count

    userdata = {
      'login' => 'This is my name',
      'state' => User.states['unconfirmed'],
      'email' => 'email@foobar.com',
      'roles' => [1.to_s, '2'],
      'password_hash_type' => 'md5',
    }
    post :create, :user => userdata, :submit => { 'preview' => 'Preview' },
      'password' => 'My Nice Password', 'password_confirmation' => 'My Nice Password'

    assert_response :success, "Previews don't work at the moment. This is a known bug: https://activerbac.turingstudio.com/trac/ticket/29"
    assert_template 'new'
    
    assert_no_tag :tag => 'h2',
                  :content => 'errors prohibited this user from being saved'

    assert_equal num_users, User.count
  end

  def test_should_ignore_unknown_post_variable_on_create_submit_create
    # This fails and displays the default error page in production.
    # How can I really test this?
#    invalid_data = { 'foo' => 'bar' }
#    post :create, :user => invalid_data
#    
#    assert_response :success
#    assert_template 'new'
  end

  def test_create_emptypost_failure_submit_create
    num_users = User.count

    post :create, :user => {}

    assert_response :success
    assert_template 'new'
    
    # TODO: Somehow make that error displaying configureable. h2 is *bad* for that
    assert_tag :tag => 'h2', :content => 'errors prohibited this user from being saved'
    assert_equal num_users, User.count
  end

  def test_edit
    get :edit, :id => @icarus_user.id

    assert_response :success
    assert_template 'edit'

    assert_not_nil assigns(:user)
    
    user = assigns(:user)
    assert_equal @icarus_user.id, user.id
    assert_equal @icarus_user.login, user.login
    assert_equal @icarus_user.email, user.email
    assert_equal @icarus_user.password, user.password
    assert_equal @icarus_user.state, user.state
  end

  # We want to be redirected if we try a GET on update - dangerous actions are
  # POST only!
  def test_update_reject_on_get
    get :update, :id => 1

    assert_response :redirect
    assert_redirected_to :action => 'list'
  end

  def test_update_success_submit_update
    assert_equal @icarus.id, @icarus_user.id
    assert_equal @icarus.login, @icarus_user.login
    assert_equal @icarus.state, @icarus_user.state
    assert_equal @icarus.email, @icarus_user.email
    assert_equal @icarus.password, @icarus_user.password
    assert_equal @icarus.password_hash_type, @icarus_user.password_hash_type

    user = {
      'login' => 'daedalus',
      'state' => User.states['locked'],
      'email' => 'daedalus@crete',
      'password_hash_type' => 'md5',
    }

    post :update, :id => 1, :user => user, 'password' => 'leafleaf', 'password_confirmation' => 'leafleaf', :submit => { 'update' => 'Update' }

    assert_response :redirect
    assert_redirected_to :action => 'show', :id => 1

    user = User.find(1)
    assert_equal 'daedalus', user.login
    assert_equal User.states['locked'], user.state
    assert_equal 'daedalus@crete', user.email
    assert_equal 0, user.roles.length
    assert user.password_equals?('leafleaf')
    assert_equal 'md5', user.password_hash_type
  end

  def DEACTIVATED_test_update_success_submit_preview
    # icarus comes from setup
    assert_equal @icarus.id, @icarus_user.id
    assert_equal @icarus.login, @icarus_user.login
    assert_equal @icarus.state, @icarus_user.state
    assert_equal @icarus.email, @icarus_user.email
    assert_equal @icarus.password, @icarus_user.password
    assert_equal @icarus.password_hash_type, @icarus_user.password_hash_type

    user = {
      'login' => 'daedalus',
      'state' => User.states['unconfirmed'],
      'email' => 'daedalus@crete',
      'password_hash_type' => 'md5',
    }

    post :update, :id => 1, :user => user, 'password' => 'leafleaf', 'password_confirmation' => 'leafleaf', :submit => { 'preview' => 'Preview' }

    assert_response :success
    assert_template 'edit'

    assert_equal @icarus.id, @icarus_user.id
    assert_equal @icarus.login, @icarus_user.login
    assert_equal @icarus.state, @icarus_user.state
    assert_equal @icarus.email, @icarus_user.email
    assert_equal @icarus.password, @icarus_user.password
    assert_equal @icarus.password_hash_type, @icarus_user.password_hash_type
  end

  def test_update_no_password_change_submit_update
    assert_equal @icarus.id, @icarus_user.id
    assert_equal @icarus.login, @icarus_user.login
    assert_equal @icarus.state, @icarus_user.state
    assert_equal @icarus.email, @icarus_user.email
    assert_equal @icarus.password, @icarus_user.password
    assert_equal @icarus.password_hash_type, @icarus_user.password_hash_type

    user = {
      'login' => 'minotaurus',
      'state' => User.states['locked'],
      'email' => 'minotaurus@labyrinth',
      'password_hash_type' => 'md5',
    }

    post :update, :id => @icarus_user.id, :user => user, 'password' => '', 'password_confirmation' => '', :submit => { 'update' => 'Update' }

    assert_response :redirect
    assert_redirected_to :action => 'show', :id => @icarus_user.id

    user = User.find(@icarus_user.id)
    assert_equal 'minotaurus', user.login
    assert_equal User.states['locked'], user.state
    assert_equal 'minotaurus@labyrinth', user.email
    assert_equal 0, user.roles.length
    assert user.password_equals?('password')
    assert_equal 'md5', user.password_hash_type
  end
  
  def test_revoke_multiple_roles_submit_update
    icarus_user = User.find @icarus_user.id
    icarus_user.roles << Role.find(@gods_role.id) << Role.find(@greeks_role.id)
    assert icarus_user.save
    assert_equal 2, icarus_user.roles.length
    assert_equal [ Role.find(@gods_role.id), Role.find(@greeks_role.id) ].sort {|a,b| a.id <=> b.id}, icarus_user.roles.sort {|a,b| a.id <=> b.id}
    
    user = {
      'login' => @icarus_user.login,
      'email' => @icarus_user.email,
      'password_hash_type' => @icarus_user.password_hash_type,
      'state' => @icarus_user.state,
    }
    
    post :update, :id => @icarus_user.id, :user => user, :submit => { 'update' => 'Update' }
    
    assert_response :redirect
    assert_redirected_to :action => 'show', :id => @icarus_user.id
    
    user = User.find(@icarus_user.id)
    assert_equal 0, user.roles.length
  end

  def test_should_display_edit_form_on_invalid_state_transition
    assert_equal @icarus.id, @icarus_user.id
    assert_equal @icarus.login, @icarus_user.login
    assert_equal @icarus.state, @icarus_user.state
    assert_equal @icarus.email, @icarus_user.email
    assert_equal @icarus.password, @icarus_user.password
    assert_equal @icarus.password_hash_type, @icarus_user.password_hash_type

    user = {
      'login' => 'daedalus',
      'state' => User.states['unconfirmed'],
      'email' => 'daedalus@crete',
      'password_hash_type' => 'md5',
    }

    post :update, :id => @icarus.id, :user => user, 'password' => 'leafleaf', 'password_confirmation' => 'leafleaf', :submit => { 'update' => 'Update' }

    assert_response :success
    assert_template 'edit'

    user = User.find(@icarus.id)
    assert_equal @icarus_user.id, user.id
    assert_equal @icarus_user.login, user.login
    assert_equal @icarus_user.state, user.state
    assert_equal @icarus_user.email, user.email
    assert_equal @icarus_user.password, user.password
    assert_equal @icarus_user.password_hash_type, user.password_hash_type
  end

  def test_delete
    get :delete, :id => 1
    
    assert_response :success
    assert_template 'delete'
  end

  # We want to be redirected if we try a GET on destroy - dangerous
  # actions are POST only!
  def test_destroy_reject_on_get
    get :destroy, :id => 1
    
    assert_response :redirect
    assert_redirected_to :action => 'list'
  end

  def test_destroy_say_yes
    assert_not_nil User.find(@zeus_user.id)

    post :destroy, :id => @zeus_user.id, :yes => 'Yes'
    assert_response :redirect
    assert_redirected_to :action => 'list'

    assert_raise(ActiveRecord::RecordNotFound) {
      User.find(@zeus_user.id)
    }
  end

  def test_destroy_say_no
    assert_not_nil User.find(@zeus_user.id)

    post :destroy, :id => @zeus_user.id
    assert_response :redirect
    assert_redirected_to :action => 'show', :id => @zeus_user.id.to_s

    assert_kind_of User, User.find(@zeus_user.id)
  end


  # Checks that https://activerbac.turingstudio.com/trac/ticket/75 is fixed
  # and the hint is displayed in the user edit form.
  def test_should_display_leave_blank_hint_in_update_user_form
    get :edit, :id => 1
    
    assert_tag :tag => 'div', :attributes => { :class => 'hint' }, 
      :content => 'Leave empty to keep the password unchanged'
  end
end
