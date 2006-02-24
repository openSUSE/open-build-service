require_dependency 'active_rbac/helpers/rbac_helper'

# This is the controller that provides CRUD functionality for the Group model.
class ActiveRbac::GroupController < ActiveRbac::ComponentController
  uses_component_template_root
  
  # The RbacHelper allows us to render +acts_as_tree+ AR elegantly
  helper RbacHelper
  
  # The layout this controller uses is configured in the 
  # Configuration class
  layout config.controller[:layout]

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

  # Displays a tree of all groups.
  def list
    @groups = Group.find_all
  end

  # Show a group identified by the +:id+ path fragment in the URL.
  def show
    @group = Group.find(params[:id].to_i)

  rescue ActiveRecord::RecordNotFound
    flash[:error] = 'This group could not be found.'
    redirect_to :action => 'list'
  end

  # Displays a form to create a new group. Posts to the #create action.
  def new
    @group = Group.new
  end

  # Creates a new group. +create+ is only accessible via POST and renders
  # the same form as #new on validation errors.
  def create
    @group = Group.new(params[:group])

    # get an array of roles and set the role associations
    params[:group][:roles] = [] if params[:group][:roles].nil?
    roles = params[:group][:roles].collect { |i| Role.find(i) }
    @group.roles = roles
  
    # set parent manually
    @group.parent = Group.find(params[:group][:parent]) unless params[:group][:parent].to_s.empty?
  
    # assign properties to group
    if @group.save
      flash[:notice] = 'The group has been created successfully.'
      redirect_to :action => 'show', :id => @group
    else
      render :action => 'new'
    end

  rescue ActiveRecord::RecordNotFound
    flash[:error] = 'You sent an invalid request.'
    redirect_to :action => 'list'
  end

  # Loads the group identified by the :id parameter from the url fragment from
  # the database and displays an edit form with the group.
  def edit
    @group = Group.find(params[:id].to_i)

  rescue ActiveRecord::RecordNotFound
    flash[:error] = 'This group could not be found.'
    redirect_to :action => 'list'
  end

  # Updates a group record in the database. +update+ is only accessible via
  # POST and renders the same form as #edit on validation errors.
  def update
    @group = Group.find(params[:id].to_i)

    # get an array of roles and set the role associations
    params[:group][:roles] = [] if params[:group][:roles].nil?
    roles = params[:group][:roles].collect { |i| Role.find(i) }
    @group.roles = roles

    # set parent manually
    if params[:group][:parent].to_s.empty?
      @group.parent = nil
    else
      @group.parent = Group.find(params[:group][:parent])
    end

    # Bulk-Assign the other attributes from the form.
    if @group.update_attributes(params[:group])
      flash[:notice] = 'Group has been updated successfully.'
      redirect_to :action => 'show', :id => @group.to_param
    else
      render :action => 'edit'
    end

  rescue RecursionInTree
    @role.errors.add :parent, "must not be a descendant of itself"
    render :action => 'edit'
  rescue ActiveRecord::RecordNotFound
    flash[:error] = 'You sent an invalid request.'
    redirect_to :action => 'list'
  end

  # Loads the group specified by the :id parameters from the url fragment from
  # the database and displays a "Do you really want to delete it?" form. It
  # posts to #destroy.
  def delete
    @group = Group.find(params[:id].to_i)

  rescue ActiveRecord::RecordNotFound
    flash[:error] = 'This group could not be found.'
    redirect_to :action => 'list'
  end

  # Removes a group record from the database. +destroy+ is only accessible
  # via POST. If the answer to the form in #delete has not been "Yes", it 
  # redirects to the #show action with the selected's group's ID.
  def destroy
    if not params[:yes].nil?
      Group.find(params[:id].to_i).destroy
      flash[:notice] = 'The group has been deleted successfully.'
      redirect_to :action => 'list'
    else
      flash[:notice] = 'The group has not been deleted.'
      redirect_to :action => 'show', :id => params[:id]
    end

  rescue CantDeleteWithChildren
    flash[:error] = "You have to delete or move the group's children before attempting to delete the group itself."
    redirect_to :action => 'show', :id => params[:id]
  rescue ActiveRecord::RecordNotFound
    flash[:error] = 'This group could not be found.'
    redirect_to :action => 'list'
  end
end