module Triggerable
  def set_project
    # By default we operate on the package association
    @project = @token.package.try(:project)
    validate_token_project

    # If the token has no package, let's find one from the parameters or the step intructions
    @project ||= Project.get_by_name(@project_name)
    # Remote projects are read-only, can't trigger something for them.
    # See https://github.com/openSUSE/open-build-service/wiki/Links#project-links
    raise Project::Errors::UnknownObjectError, "Sorry, triggering tokens for remote project \"#{@project_name}\" is not possible." unless @project.is_a?(Project)
  end

  def set_package(package_find_options: {}) # rubocop:disable Metrics/CyclomaticComplexity
    # By default we operate on the package association
    @package = @token.package
    validate_token_package

    # If the token has no package, let's find one from the parameters
    if @package_name.present?
      package_find_options = @token.package_find_options if package_find_options.blank?

      return if (@package = Package.get_by_project_and_name(@project.name, @package_name, package_find_options))
    end
    return if @package
    return unless project_links_to_remote?

    # In remote or scmsync case we have no database object, but the package
    # may still be there. It will get validated by the backend.
    # Strip multibuild part as the code will add it later again in the model
    @package ||= @package_name.gsub(/:.*/, '')

    # TODO: This should not happen right? But who knows...
    raise ActiveRecord::RecordNotFound unless @package
  end

  # FIXME: Use the version from Webui::WebuiController instead
  def set_object_to_authorize
    @token.object_to_authorize = package_from_project_link? ? @project : @package
  end

  def set_multibuild_flavor
    # Do NOT use @package.multibuild_flavor? here because the flavor need to be checked for the right source revision
    @multibuild_container = @package_name.gsub(/.*:/, '') if @package_name.present? && @package_name.include?(':')
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
