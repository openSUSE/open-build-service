class ActiveRbac::RoleController < ActiveRbac::ComponentController
  # The RbacHelper allows us to render +acts_as_tree+ AR elegantly
  helper RbacHelper

  skip_before_filter :validate_params, :only => [:update]

  # Use the configured layout.
  layout "rbac.rhtml"

  # Simply redirects to #list.
  def index
    redirect_to :action => 'list'
  end

  # Displays all roles known to the system as trees.
  def list
    # We don't use pagination here since we want to display the roles in a
    # nice tree. Additionally, there won't be more than ~100 roles in a
    # normal scenario anyway - far less!
    @roles = Role.find(:all)
  end

  # Show a role identified by the +:id+ path fragment in the URL.
  def show
    @role = Role.find(params[:id])

  rescue ActiveRecord::RecordNotFound
    flash[:error] = 'The role could not be found'
    redirect_to :action => 'list'
  end

  # Display a form to create a new role on GET. Handle the form submission
  # from this form on POST and display errors if there were any.
  def create

    if request.get?
      @role = Role.new
    else
      @role = Role.new(params[:role])

      # assign parent role
      if not params[:role][:parent].to_s.empty?
        @role.parent = Role.find(params[:role][:parent].to_i)
      end

      if @role.save
        # set the roles's static permissions to the static permission from the parameters
        params[:role][:static_permissions] = [] if params[:role][:static_permissions].nil?
        @role.static_permissions = params[:role][:static_permissions].collect { |i| StaticPermission.find(i) }

        # the above should be successful if we reach here; otherwise we
        # have an exception and reach the rescue block below
        flash[:success] = 'Role has been created successfully.'
        redirect_to :action => 'show', :id => @role.id
      else
        render :action => 'create'
      end
    end

  rescue ActiveRecord::RecordNotFound
    flash[:error] = 'You sent an invalid request.'
    redirect_to :action => 'list'
  end

  # Display a form to edit the given role on GET. Handle the form submission
  # of this form on POST and display errors if any occurred.
  def update

    if request.get?
      @role = Role.find(params[:id].to_i)
    else
      @role = Role.find(params[:id].to_i)

      # set parent role
      if not params[:role][:parent].to_s.empty?
        @role.parent = Role.find(params[:role][:parent])
      else
        @role.parent = nil
      end

      # get an array of static permissions and set the permission associations
      params[:role][:static_permissions] = [] if params[:role][:static_permissions].nil?
      permissions = params[:role][:static_permissions].collect { |i| StaticPermission.find(i) }
      @role.static_permissions = permissions

      if @role.update_attributes(params[:role])
        flash[:success] = 'Role has been updated successfully.'
        redirect_to :action => 'show', :id => @role.id
      else
        render :action => 'update'
      end
    end

  rescue RecursionInTree
    @role.errors.add :parent, "must not be a descendant of itself"
    render :action => 'update'
  rescue ActiveRecord::RecordNotFound
    flash[:error] = 'You sent an invalid request.'
    redirect_to :action => 'list'
  end

  # Display a confirmation form (which asks "do you really want to delete this
  # role?") on GET. Handle the form submission on POST. Redirect to the "list"
  # action if the role has been deleted and redirect to the "show" action with
  # these role's id if it has not been deleted.
  def delete
    @role = Role.find(params[:id].to_i)

    if request.get?
      # render only
    else
      if not params[:yes].nil?
        @role.destroy
        flash[:success] = 'The role has been deleted successfully.'
        redirect_to :action => 'list'
      else
        flash[:success] = 'The role has not been deleted.'
        redirect_to :action => 'show', :id => @role.id
      end
    end

  rescue CantDeleteWithChildren
    flash[:error] = "You have to delete or move the role's children before attempting to delete the role itself."
    redirect_to :action => 'show', :id => sanitize_to_id( params[:id] )
  rescue ActiveRecord::RecordNotFound
    flash[:error] = 'This role could not be found.'
    redirect_to :action => 'list'
  end
end
