module Triggerable
  def set_project
    # By default we operate on the package association
    @project = @token.package.try(:project)
    validate_token_project

    # If the token has no package, let's find one from the parameters/step intructions
    @project ||= Project.find_by(name: @project_name)
    raise Project::Errors::UnknownObjectError, "Project not found: #{@project_name}" unless @project
  end

  def set_package(package_find_options: {})
    package_find_options = @token.package_find_options if package_find_options.blank?
    # By default we operate on the package association
    @package = @token.package
    validate_token_package

    # If the token has no package, let's find one from the parameters
    if @package_name.present?
      @package ||= Package.get_by_project_and_name(@project.name,
                                                   @package_name,
                                                   package_find_options)
    end
    return unless project_links_to_remote?

    # The token has no package, we did not find a package in the database but the project has a link to remote.
    # See https://github.com/openSUSE/open-build-service/wiki/Links#project-links
    # In this case, we will try to trigger with the user input, no matter what it is
    @package ||= Package.striping_multibuild_suffix(@package_name)
    # TODO: This should not happen right? But who knows...
    raise ActiveRecord::RecordNotFound unless @package
  end

  # FIXME: Use the version from Webui::WebuiController instead
  def set_object_to_authorize
    @token.object_to_authorize = package_from_project_link? ? @project : @package
  end

  def set_multibuild_flavor
    @multibuild_flavor = Package.multibuild_flavor(@package_name) if @package_name.present?
  end

  private

  def package_from_project_link?
    # a remote package is always included via project link
    !(@package.is_a?(Package) && @package.project == @project)
  end

  def project_links_to_remote?
    @project.scmsync.present? || @project.links_to_remote?
  end

  def validate_token_project
    raise Trigger::Errors::InvalidProject if @project && @project_name && (@project_name != @project.name)
  end

  def validate_token_package
    raise Trigger::Errors::InvalidPackage if @package && @package_name && (@package_name != @package.name)
  end
end
