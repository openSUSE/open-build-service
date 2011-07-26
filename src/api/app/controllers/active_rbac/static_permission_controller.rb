# This is the controller that provides CRUD functionality for the
# StaticPermission model.
class ActiveRbac::StaticPermissionController < ActiveRbac::ComponentController
  # The RbacHelper allows us to render +acts_as_tree+ AR elegantly
  helper RbacHelper

  # Use the configured layout.
  layout "rbac.rhtml"

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
    flash[:error] = 'This permission could not be found.'
    redirect_to :action => 'list'
  end

  # Display a form to create a new permission on GET. Handle the form
  # submission from this form on POST and display errors if there were any.
  def create

    if request.get?
      @permission = StaticPermission.new
    else
      @permission = StaticPermission.new(params[:permission])

      # assign properties to group
      if @permission.save
        flash[:success] = 'The permission has been created successfully.'
        redirect_to :action => 'show', :id => @permission.id
      else
        render :action => 'create'
      end
    end

  rescue ActiveRecord::RecordNotFound
    flash[:error] = 'You sent an invalid request.'
    redirect_to :action => 'list'
  end

  # Display a form to edit the given permission on GET. Handle the form submission
  # of this form on POST and display errors if any occurred.
  def update
    @permission = StaticPermission.find(params[:id])

    if request.get?
      # render only
    else
      # Bulk-Assign the other attributes from the form.
      if @permission.update_attributes(params[:permission])
        flash[:success] = 'Permission has been updated successfully.'
        redirect_to :action => 'show', :id => @permission.id
      else
        render :action => 'update'
      end
    end

  rescue ActiveRecord::RecordNotFound
    flash[:error] = 'This permission could not be found!'
    redirect_to :action => 'list'
  end

  # Display a confirmation form (which asks "do you really want to delete this
  # role?") on GET. Handle the form submission on POST. Redirect to the "list"
  # action if the role has been deleted and redirect to the "show" action with
  # these role's id if it has not been deleted.
  def delete
    @permission = StaticPermission.find(params[:id])

    if request.get?
      # render only
    else
      if not params[:yes].nil?
        @permission.destroy
        flash[:success] = 'The permission has been deleted successfully'
        redirect_to :action => 'list'
      else
        flash[:success] = 'The permission has not been deleted.'
        redirect_to :action => 'show', :id => @permission.id
      end
    end

  rescue ActiveRecord::RecordNotFound
    flash[:error] = 'This group could not be found.'
    redirect_to :action => 'list'
  end
end
