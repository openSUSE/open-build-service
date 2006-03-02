require_dependency 'active_rbac/helpers/rbac_helper'

# This is the controller that provides CRUD functionality for the User model.
class ActiveRbac::UserController < ActiveRbac::ComponentController
  uses_component_template_root

  # The RbacHelper allows us to render +acts_as_tree+ AR elegantly
  helper RbacHelper

  # The layout this controller uses is configured in the 
  # Configuration class
  layout config.controller[:layout]
  
  before_filter :require_admin  

  # We force users to use POST on the state changing actions.
  verify :method       => :post,
         :only         => [ :create, :update, :destroy ],
         :redirect_to  => { :action => 'list' },
         :add_flash    => { :error => 'You sent an invalid request!' }

  # We force users to use GET on all other methods, though.
  verify :method       => :get,
         :only         => [ :index, :list, :show, :new, :delete ],
         :redirect_to  => { :action => 'list' },
         :add_flash    => { :error => 'You sent an invalid request!' }
  

  # Simply redirects to #list
  def index
    redirect_to :action  => 'list'
  end

  # Displays a paginated table of users.
  def list
    @user_pages, @users = paginate :user, :per_page => 20
  end

  # Show a user identified by the +:id+ path fragment in the URL.
  def show
    @user = User.find(params[:id].to_i)

  rescue ActiveRecord::RecordNotFound
    flash[:notice] = 'This user could not be found.'
    redirect_to :action => 'list'
  end

  # Displays a form to create a new user. Posts to the #create action.
  def new
    @user = User.new
  end

  # Creates a new user. +create+ is only accessible via POST and renders
  # the same form as #new on validation errors.
  def create
    # Set password and password_confirmation into [:user] parameters
    params[:user][:password] = params[:password]
    params[:user][:password_confirmation] = params[:password_confirmation]
    
    @user = User.new(params[:user])

    # Set password hash type seperatedly because it is protected
    @user.password_hash_type = params[:user][:password_hash_type]
    
    # get an array of roles and set the role associations
    params[:user][:roles] = [] if params[:user][:roles].nil?
    roles = params[:user][:roles].collect { |i| Role.find(i) }
    @user.roles = roles

    # get an array of groups and set the group associations
    params[:user][:groups] = [] if params[:user][:groups].nil?
    groups = params[:user][:groups].collect { |i| Group.find(i) }
    @user.groups = groups

    # assign properties to user
    if @user.save
      flash[:notice] = 'User was created successfully.'
      redirect_to :action => 'show', :id => @user.to_param
    else
      render :action => 'new'
    end

  rescue ActiveRecord::RecordNotFound
    flash[:error] = 'You sent an invalid request.'
    redirect_to :action => 'list'
  end

  # Loads the user identified by the :id parameter from the url fragment from
  # the database and displays an edit form with the user.
  def edit
    @user = User.find(params[:id])

  rescue ActiveRecord::RecordNotFound
    flash[:error] = 'You sent an invalid request.'
    redirect_to :action => 'list'
  end

  # Updates a user record in the database. +update+ is only accessible via
  # POST and renders the same form as #edit on validation errors.
  def update
    @user = User.find(params[:id])

    # get an array of roles and set the role associations
    params[:user][:roles] = [] if params[:user][:roles].nil?
    roles = params[:user][:roles].collect { |i| Role.find(i) }
    @user.roles = roles

    # get an array of groups and set the group associations
    params[:user][:groups] = [] if params[:user][:groups].nil?
    groups = params[:user][:groups].collect { |i| Group.find(i) }
    @user.groups = groups

    # Set password and password_confirmation into [:user] parameters
    unless params[:password].to_s == ""
      params[:user][:password] = params[:password]
      params[:user][:password_confirmation] = params[:password_confirmation]
    end

    # Set password hash type seperatedly because it is protected
    @user.password_hash_type = params[:user][:password_hash_type] if params[:user][:password_hash_type] != @user.password_hash_type

    # Bulk-Assign the other attributes from the form.
    if @user.update_attributes(params[:user])
      flash[:notice] = 'User was successfully updated.'
      redirect_to :action => 'show', :id => @user.to_param
    else
      render :action => 'edit'
    end

  rescue InvalidStateTransition # this should really go into User.validate!
    flash[:error] = 'You have selected an invalid state.'
    redirect_to :action => 'edit', :id => @user
  rescue ActiveRecord::RecordNotFound
    flash[:error] = 'You sent an invalid request.'
    redirect_to :action => 'list'
  end
  
  # Loads the user specified by the :id parameters from the url fragment from
  # the database and displays a "Do you really want to delete it?" form. It
  # posts to #destroy.
  def delete
    @user = User.find(params[:id])
  rescue
    flash[:notice] = 'Invalid user specified!'
    redirect_to :action => 'list'
  end

  # Removes a user record from the database. +destroy+ is only accessible
  # via POST. If the answer to the form in #delete has not been "Yes", it 
  # redirects to the #show action with the selected's userp's ID.
  def destroy
    if not params[:yes].nil?
      User.find(params[:id]).destroy
      flash[:notice] = 'The user has been deleted successfully'
      redirect_to :action => 'list'
    else
      flash[:notice] = 'The user has not been deleted.'
      redirect_to :action => 'show', :id => params[:id]
    end
    
  rescue ActiveRecord::RecordNotFound
    flash[:error] = 'This user could not be found.'
    redirect_to :action => 'list'
  end
end
