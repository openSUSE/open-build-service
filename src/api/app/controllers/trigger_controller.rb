class TriggerController < ApplicationController
  ALLOWED_GITLAB_EVENTS = ['Push Hook', 'Tag Push Hook', 'Merge Request Hook'].freeze

  # Authentication happens with tokens, so extracting the user is not required
  skip_before_action :extract_user
  # Authentication happens with tokens, so no login is required
  skip_before_action :require_login
  # GitLab/Github send data as parameters which are not strings
  skip_before_action :validate_params
  after_action :verify_authorized

  before_action :validate_gitlab_event, if: :gitlab_webhook?
  before_action :set_token
  before_action :set_project
  before_action :set_package
  before_action :set_object_to_authorize
  # set_multibuild_flavor needs to run after the set_object_to_authorize callback
  append_before_action :set_multibuild_flavor
  include Trigger::Errors

  def create
    authorize @token
    @token.user.run_as do
      @token.call(project: @project, package: @package, repository: params[:repository], arch: params[:arch])
      render_ok
    end
  end

  private

  def gitlab_webhook?
    request.env['HTTP_X_GITLAB_EVENT'].present?
  end

  def validate_gitlab_event
    raise InvalidToken unless request.env['HTTP_X_GITLAB_EVENT'].in?(ALLOWED_GITLAB_EVENTS)
  end

  # AUTHENTICATION
  def set_token
    @token = ::TriggerControllerService::TokenExtractor.new(request).call
    raise InvalidToken unless @token
  end

  def set_project
    # By default we operate on the package association
    @project = @token.package.try(:project)
    # If the token has no package, let's find one from the parameters
    @project ||= Project.get_by_name(params[:project])
    # Remote projects are read-only, can't trigger something for them.
    # See https://github.com/openSUSE/open-build-service/wiki/Links#project-links
    raise Project::Errors::UnknownObjectError, "Sorry, triggering tokens for remote project \"#{params[:project]}\" is not possible." unless @project.is_a?(Project)
  end

  def set_package
    # By default we operate on the package association
    @package = @token.package
    # If the token has no package, let's find one from the parameters
    @package ||= Package.get_by_project_and_name(@project,
                                                 params[:package],
                                                 @token.package_find_options)
    return unless @project.links_to_remote?

    # The token has no package, we did not find a package in the database but the project has a link to remote.
    # See https://github.com/openSUSE/open-build-service/wiki/Links#project-links
    # In this case, we will try to trigger with the user input, no matter what it is
    @package ||= params[:package]

    # TODO: This should not happen right? But who knows...
    raise ActiveRecord::RecordNotFound unless @package
  end

  def set_object_to_authorize
    # By default we authorize against the package we found in set_package
    @token.object_to_authorize = @package
    # And only if we consider multibuild or project links we might need to do more complicated things...
    return unless @token.follow_links?

    # We found a local package
    @token.object_to_authorize = if @package.is_a?(Package)
                                   # If the package is coming through a project link, we authorize the project
                                   # See https://github.com/openSUSE/open-build-service/wiki/Links#project-links
                                   package_from_project_link? ? @project : @package
                                   # We did not find a local package, have to authorize the project
                                 else
                                   @project
                                 end
  end

  def set_multibuild_flavor
    # Only if we consider multibuild or project links we might need to do more complicated things...
    return unless @token.follow_links?
    # @package is a String if @project has a project link, no need to do anything then.
    return unless @package.is_a?(Package)

    # We use the package parameter if it is a valid multibuild flavor of the package
    # See https://github.com/openSUSE/open-build-service/wiki/Links#mulitbuild-packages
    @package = params[:package] if @package.multibuild_flavor?(params[:package])
  end

  def package_from_project_link?
    @package.project != @project
  end
end
