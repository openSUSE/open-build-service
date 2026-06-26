class BranchPackage::SetTargetProject
  def initialize(params)
    @target_project = params[:target_project] || nil
    @request = params[:request] || nil
    @project = params[:project] || nil
    @package = params[:package] || nil
    @attribute = params[:attribute] || 'OBS:Maintained'
    @autocleanup = params[:autocleanup] || 'false'
  end

  def valid?
    @target_project.blank? || Project.valid_name?(@target_project)
  end

  def target_project
    return @target_project if @target_project

    if @request
      User.session!.branch_project_name("REQUEST_#{@request}")
    elsif @project
      nil # to be set later after first source location lookup
    else
      target_project_name
    end
  end

  def auto_cleanup
    if @target_project
      ::Configuration.cleanup_after_days if auto_cleanup?
    else
      ::Configuration.cleanup_after_days
    end
  end

  private

  def target_project_name
    target_project_name = user_branch_project_name
    target_project_name += ":#{@package}" if @package
    target_project_name
  end

  def user_branch_project_name
    User.session!.branch_project_name(@attribute.tr(':', '_'))
  end

  def auto_cleanup?
    @autocleanup == 'true'
  end
end
