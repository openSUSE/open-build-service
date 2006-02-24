require_dependency 'active_rbac/helpers/rbac_helper'

# This is the controller that provides CRUD functionality for the 
# StaticPermission model.
class ActiveRbac::StaticPermissionController < ActiveRbac::ComponentController
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

  # Displays a tree of all static permission.
  def list
    @permission_pages, @permissions = paginate :static_permission, :per_page => 20
  end

  # Show a static permission identified by the +:id+ path fragment in the URL.
  def show
    @permission = StaticPermission.find(params[:id])

  rescue ActiveRecord::RecordNotFound
    flash[:notice] = 'This permission could not be found.'
    redirect_to :action => 'list'
  end

  # Displays a form to create a new static permission. Posts to the #create
  # action.
  def new
    @permission = StaticPermission.new
  end

  # Creates a new static permission. +create+ is only accessible via POST and 
  # renders the same form as #new on validation errors.
  def create
    @permission = StaticPermission.new(params[:permission])

    # assign properties to group
    if @permission.save
      flash[:notice] = 'The permission has been created successfully.'
      redirect_to :action => 'show', :id => @permission.id
    else
      render :action => 'new'
    end
    
  rescue ActiveRecord::RecordNotFound
    flash[:error] = 'You sent an invalid request.'
    redirect_to :action => 'list'
  end

  # Loads the static permission identified by the :id parameter from the url
  # fragment from the database and displays an edit form with the static
  # permission.
  def edit
    @permission = StaticPermission.find(params[:id])
  rescue
    flash[:notice] = 'Invalid permission given!'
    redirect_to :action => 'list'
  end

  # Updates a static permission record in the database. +update+ is only 
  # accessible via POST and renders the same form as #edit on validation 
  # errors.
  def update
    @permission = StaticPermission.find(params[:id])

    # Bulk-Assign the other attributes from the form.
    if @permission.update_attributes(params[:permission])
      flash[:notice] = 'Permission has been updated successfully.'
      redirect_to :action => 'show', :id => @permission.to_param
    else
      render :action => 'edit'
    end

  rescue ActiveRecord::RecordNotFound
    flash[:notice] = 'This permission could not be found!'
    redirect_to :action => 'list'
  end

  # Loads the static permission specified by the :id parameters from the url 
  # fragment from the database and displays a "Do you really want to delete 
  # it?" form. It posts to #destroy.
  def delete
    @permission = StaticPermission.find(params[:id])
    
  rescue ActiveRecord::RecordNotFound
    flash[:notice] = 'This permission could not be found!'
    redirect_to :action => 'list'
  end

  # Removes a static permission record from the database. +destroy+ is only 
  # accessible via POST. If the answer to the form in #delete has not been 
  # "Yes", it redirects to the #show action with the selected's permission's 
  # ID.
  def destroy
    if not params[:yes].nil?
      StaticPermission.find(params[:id]).destroy
      flash[:notice] = 'The permission has been deleted successfully'
      redirect_to :action => 'list'
    else
      flash[:notice] = 'The permission has not been deleted.'
      redirect_to :action => 'show', :id => params[:id]
    end

  rescue ActiveRecord::RecordNotFound
    flash[:error] = 'This group could not be found.'
    redirect_to :action => 'list'
  end
end
