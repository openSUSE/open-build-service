class TriggerController < ApplicationController
  ALLOWED_GITLAB_EVENTS = ['Push Hook', 'Tag Push Hook', 'Merge Request Hook'].freeze

  validate_action rebuild: { method: :post, response: :status }
  validate_action release: { method: :post, response: :status }
  validate_action runservice: { method: :post, response: :status }

  # Authentication happens with tokens, so extracting the user is not required
  skip_before_action :extract_user
  # Authentication happens with tokens, so no login is required
  skip_before_action :require_login
  # TODO: check if we really need to skip this before action
  # new gitlab versions send other data as parameters, which we may need to ignore here. Like the project hash.
  skip_before_action :validate_params

  before_action :validate_gitlab_event
  before_action :set_token
  before_action :set_package

  include Trigger::Errors

  def create
    authorize @token
    @token.user.run_as do
      # authentication   # Done
      # get token        # Done
      # pundit           # TODO
      @token.call(repository: params[:repository], arch: params[:arch])
      render_ok
    end
  end

  # FIXME: Redirect this via routes
  def runservice
    create
  end

  private

  # AUTHENTICATION
  def set_token
    @token = ::TriggerControllerService::TokenExtractor.new(request).call
  end

  def validate_gitlab_event
    return unless request.env['HTTP_X_GITLAB_EVENT']

    raise InvalidToken unless request.env['HTTP_X_GITLAB_EVENT'].in?(ALLOWED_GITLAB_EVENTS)
  end

  def set_package
    # We need to store in memory the package in order to do authorization
    @token.package_from_association_or_params = @token.package ||
                                                Package.get_by_project_and_name(params[:project],
                                                                                params[:package],
                                                                                @token.package_find_options)
    # This can happen due to the Package.get_by_project_and_name method
    raise ActiveRecord::RecordNotFound if @token.package_from_association_or_params.nil?
  end

  def token_params
    params.permit(:project, :package, :repository, :arch)
  end
end
