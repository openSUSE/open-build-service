# This is the controller that provides CRUD functionality for the Group model.
class ActiveRbac::GroupController < ActiveRbac::ComponentController
  # The RbacHelper allows us to render +acts_as_tree+ AR elegantly
  helper RbacHelper

  skip_before_filter :validate_params, :only => [:create, :update]

  # Use the configured layout.
  layout "rbac.rhtml"

  # Simply redirects to #list
  def index
    redirect_to :action  => 'list'
  end

  # Displays a tree of all groups.
  def list
    @groups = Group.find(:all)
  end

  # Show a group identified by the +:id+ path fragment in the URL.
  def show
    @group = Group.find(params[:id].to_i)

  rescue ActiveRecord::RecordNotFound
    flash[:error] = 'This group could not be found.'
    redirect_to :action => 'list'
  end

  # Display a form to create a new group on GET. Handle the form submission
  # from this form on POST and display errors if there were any.
  def create

    if request.get?
      @group = Group.new
    else
      @group = Group.new(params[:group])

      # set parent manually
      @group.parent = Group.find(params[:group][:parent]) unless params[:group][:parent].to_s.empty?

      # assign properties to group
      if @group.save
        # set the groups's roles to the roles from the parameters
        params[:group][:roles] = [] if params[:group][:roles].nil?
        @group.roles = params[:group][:roles].collect { |i| Role.find(i) }

        # the above should be successful if we reach here; otherwise we
        # have an exception and reach the rescue block below
        flash[:success] = 'The group has been created successfully.'
        redirect_to :action => 'show', :id => @group.id
      else
        render :action => 'create'
      end
    end

  rescue ActiveRecord::RecordNotFound
    flash[:error] = 'You sent an invalid request.'
    redirect_to :action => 'list'
  end

  # Display a form to edit the given group on GET. Handle the form submission
  # of this form on POST and display errors if any occured.
  def update
    @group = Group.find(params[:id].to_i)

    if request.get?
      # render only
    else
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
        flash[:success] = 'Group has been updated successfully.'
        redirect_to :action => 'show', :id => @group.id
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
  # group?") on GET. Handle the form submission on POST. Redirect to the "list"
  # action if the group has been deleted and redirect to the "show" action with
  # these group's id if it has not been deleted.
  def delete
    @group = Group.find(params[:id].to_i)

    if request.get?
      # render only
    else
      if not params[:yes].nil?
        @group.destroy
        flash[:success] = 'The group has been deleted successfully.'
        redirect_to :action => 'list'
      else
        flash[:success] = 'The group has not been deleted.'
        redirect_to :action => 'show', :id => @group.id
      end
    end

  rescue CantDeleteWithChildren
    flash[:error] = "You have to delete or move the group's children before attempting to delete the group itself."
    redirect_to :action => 'show', :id => sanitize_to_id( params[:id] )
  rescue ActiveRecord::RecordNotFound
    flash[:error] = 'This group could not be found.'
    redirect_to :action => 'list'
  end
end
