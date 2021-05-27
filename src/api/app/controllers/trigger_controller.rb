class TriggerController < ApplicationController
  ALLOWED_GITLAB_EVENTS = ['Push Hook', 'Tag Push Hook', 'Merge Request Hook'].freeze

  # Authentication happens with tokens, so extracting the user is not required
  skip_before_action :extract_user
  # Authentication happens with tokens, so no login is required
  skip_before_action :require_login
  # GitLab/Github send data as parameters which are not strings
  # e.g. integer PR number (GitHub) and project hash (GitLab)
  skip_before_action :validate_params, if: :scm_webhook?
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
      opts = { project: @project, package: @package, repository: params[:repository], arch: params[:arch] }
      opts[:multibuild_flavor] = @multibuild_container if @multibuild_container.present?
      @token.call(opts)
      render_ok
    end
  end

  private

  def gitlab_webhook?
    request.env['HTTP_X_GITLAB_EVENT'].present?
  end

  def github_webhook?
    request.env['HTTP_X_GITHUB_EVENT'].present?
  end

  def scm_webhook?
    gitlab_webhook? || github_webhook?
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
    @token.object_to_authorize = package_from_project_link? ? @project : @package
  end

  def set_multibuild_flavor
    # Do NOT use @package.multibuild_flavor? here because the flavor need to be checked for the right source revision
    @multibuild_container = params[:package].gsub(/.*:/, '') if params[:package].present? && params[:package].include?(':')
  end

  def package_from_project_link?
    # a remote package is always included via project link
    !(@package.is_a?(Package) && @package.project == @project)
  end
end
