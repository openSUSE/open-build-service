class ActiveRbac::RoleController < ActiveRbac::ComponentController
  # The RbacHelper allows us to render +acts_as_tree+ AR elegantly
  helper RbacHelper

  # Use the configured layout.
  layout ActiveRbacConfig.config(:controller_layout)

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

  # Simply redirects to #list.
  def index
    redirect_to :action => 'list'
  end

  # Displays all roles known to the system as trees.
  def list
    # We don't use pagination here since we want to display the roles in a
    # nice tree. Additionally, there won't be more than ~100 roles in a
    # normal scenario anyway - far less!
    @roles = Role.find_all
  end

  # Show a role identified by the +:id+ path fragment in the URL.
  def show
    @role = Role.find(params[:id])
    
  rescue ActiveRecord::RecordNotFound
    flash[:error] = 'The role could not be found'
    redirect_to :action => 'list'
  end

  # Displays a form to create a new role. Posts to the #create action.
  def new
    @role = Role.new
  end

  # Creates a new role. +create+ is only accessible via POST and renders
  # the same form as #new on validation errors.
  def create
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
      flash[:notice] = 'Role has been created successfully.'
      redirect_to :action => 'show', :id => @role.id
    else
      render :action => 'new'
    end
    
  rescue ActiveRecord::RecordNotFound
    flash[:error] = 'You sent an invalid request.'
    redirect_to :action => 'list'
  end

  # Loads the role identified by the :id parameter from the url fragment from
  # the database and displays an edit form with the role's data.
  def edit
    @role = Role.find(params[:id].to_i)
    
  rescue ActiveRecord::RecordNotFound
    flash[:error] = 'This role could not be found.'
    redirect_to :action => 'list'
  end

  # Updates a role record in the database. +update+ is only accessible via
  # POST and renders the same form as #edit on validation errors.
  def update
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
      flash[:notice] = 'Role has been updated successfully.'
      redirect_to :action => 'show', :id => @role
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

  # Loads the role specified by the :id parameters from the url fragment from
  # the database and displays a "Do you really want to delete it?" form. It
  # posts to #destroy.
  def delete
    @role = Role.find(params[:id])

  rescue ActiveRecord::RecordNotFound
    flash[:error] = 'This role could not be found.'
    redirect_to :action => 'list'
  end

  # Removes a role record from the database. +destroy+ is only accessible
  # via POST. If the answer to the form in #delete has not been "Yes", it 
  # redirects to the #show action with the selected's role's ID.
  def destroy
    if not params[:yes].nil?
      Role.find(params[:id].to_i).destroy
      flash[:notice] = 'The role has been deleted successfully.'
      redirect_to :action => 'list'
    else
      flash[:notice] = 'The role has not been deleted.'
      redirect_to :action => 'show', :id => params[:id]
    end

  rescue CantDeleteWithChildren
    flash[:error] = "You have to delete or move the role's children before attempting to delete the role itself."
    redirect_to :action => 'show', :id => params[:id]
  rescue ActiveRecord::RecordNotFound
    flash[:error] = 'This role could not be found.'
    redirect_to :action => 'list'
  end
end
