class TriggerController < ApplicationController
  include Triggerable
  include Trigger::Errors

  # Authentication happens with tokens, so extracting the user is not required
  skip_before_action :extract_user
  # Authentication happens with tokens, so no login is required
  skip_before_action :require_login
  # SCMs like GitLab/GitHub send data as parameters which are not strings (e.g.: GitHub - PR number is a integer, GitLab - project is a hash)
  # Other SCMs might also do this, so we're not validating parameters.
  skip_before_action :validate_params

  before_action :set_token
  before_action :validate_parameters_by_token
  before_action :check_token_enabled
  before_action :set_project_name
  before_action :set_package_name
  # From Triggerable
  before_action :set_project
  before_action :set_package
  before_action :set_object_to_authorize
  # set_multibuild_flavor needs to run after the set_object_to_authorize callback
  append_before_action :set_multibuild_flavor

  after_action :verify_authorized

  def create
    authorize @token, :trigger?

    opts = { project: @project, package: @package, repository: params[:repository], arch: params[:arch],
             targetproject: params[:targetproject], targetrepository: params[:targetrepository],
             filter_source_repository: params[:filter_source_repository] }
    opts[:multibuild_flavor] = @multibuild_container if @multibuild_container.present?
    @token.executor.run_as { @token.call(opts) }

    render_ok
  rescue ArgumentError => e
    render_error status: 400, message: e
  end

  # validate_token_type callback uses the action_name
  def rebuild
    create
  end

  # validate_token_type callback uses the action_name
  def release
    create
  end

  # validate_token_type callback uses the action_name
  def runservice
    create
  end

  private

  # AUTHENTICATION
  def set_token
    @token = ::TriggerControllerService::TokenExtractor.new(request).call
    raise InvalidToken, 'No valid token found' unless @token
  end

  def validate_parameters_by_token
    case @token.type
    when 'Token::Workflow'
      raise InvalidToken, 'Invalid token found'
    when 'Token::Rebuild', 'Token::Release'
      return if params[:project].present?
    when 'Token::Service'
      return if params[:project].present? && params[:package].present?
    end

    return if @token.package.present?

    raise MissingParameterError
  end

  def check_token_enabled
    raise Trigger::Errors::NotEnabledToken, 'This token is not enabled.' unless @token.enabled
  end

  def pundit_user
    @token.executor
  end

  def set_project_name
    @project_name = params[:project]
  end

  def set_package_name
    @package_name = params[:package]
  end
end
