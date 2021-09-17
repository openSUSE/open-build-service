class TriggerController < ApplicationController
  include Triggerable

  ALLOWED_GITLAB_EVENTS = ['Push Hook', 'Tag Push Hook', 'Merge Request Hook'].freeze

  include Pundit

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
  before_action :set_project_name
  before_action :set_package_name
  # From Triggerable
  before_action :set_project
  before_action :set_package
  before_action :set_object_to_authorize
  # set_multibuild_flavor needs to run after the set_object_to_authorize callback
  append_before_action :set_multibuild_flavor

  include Trigger::Errors

  def create
    authorize @token, :trigger?

    @token.user.run_as do
      opts = { project: @project, package: @package, repository: params[:repository], arch: params[:arch] }
      opts[:multibuild_flavor] = @multibuild_container if @multibuild_container.present?
      @token.call(opts)
      render_ok
    end
  rescue ArgumentError => e
    render_error status: 400, message: e
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

  def pundit_user
    @token.user
  end

  def set_project_name
    @project_name = params[:project]
  end

  def set_package_name
    @package_name = params[:package]
  end
end
