module Triggerable
  def set_project
    # By default we operate on the package association
    @project = @token.package.try(:project)
    # If the token has no package, let's find one from the parameters or the step intructions
    @project ||= Project.get_by_name(@project_name)
    # Remote projects are read-only, can't trigger something for them.
    # See https://github.com/openSUSE/open-build-service/wiki/Links#project-links
    raise Project::Errors::UnknownObjectError, "Sorry, triggering tokens for remote project \"#{@project_name}\" is not possible." unless @project.is_a?(Project)
  end

  def set_package(package_find_options: {})
    package_find_options = @token.package_find_options if package_find_options.blank?
    # By default we operate on the package association
    @package = @token.package

    # If the token has no package, let's find one from the parameters if we have one...
    return if @package_name.blank?

    @package ||= Package.get_by_project_and_name(@project,
                                                 @package_name,
                                                 package_find_options)
  end

  def set_object_to_authorize
    if @package.blank?
      @token.object_to_authorize = @project
    else
      @token.object_to_authorize ||= package_from_project_link? ? @project : @package
    end
  end

  def set_multibuild_flavor
    # Do NOT use @package.multibuild_flavor? here because the flavor need to be checked for the right source revision
    @multibuild_container = @package_name.gsub(/.*:/, '') if @package_name.present? && @package_name.include?(':')
  end

  def package_from_project_link?
    # a package from a remote project link is always readonly
    return true if @package.readonly?

    # a package from a local project link has always a different project than the one we want to trigger for
    @package.project != @project
  end
end
