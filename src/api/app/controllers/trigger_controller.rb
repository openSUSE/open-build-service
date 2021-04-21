class TriggerController < ApplicationController
  ALLOWED_GITLAB_EVENTS = ['Push Hook', 'Tag Push Hook', 'Merge Request Hook'].freeze

  # Authentication happens with tokens, so extracting the user is not required
  skip_before_action :extract_user
  # Authentication happens with tokens, so no login is required
  skip_before_action :require_login

  before_action :validate_gitlab_event
  before_action :set_token
  before_action :set_package

  include Trigger::Errors

  def create
    authorize @token
    @token.user.run_as do
      @token.call(params.slice(:repository, :arch))
      render_ok
    end
  end

  private

  # AUTHENTICATION
  def set_token
    @token = ::TriggerControllerService::TokenExtractor.new(request).call
    raise InvalidToken unless @token
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
end
