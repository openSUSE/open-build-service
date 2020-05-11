class Services::WebhooksController < ApplicationController
  skip_before_action :extract_user
  skip_before_action :require_login
  skip_before_action :validate_params
  before_action :validate_token, :set_package, :set_user

  def create
    if !@user.is_active? || !@user.can_modify?(@package)
      render_error message: 'Token not found or not valid.', status: 404
      return
    end

    Backend::Api::Sources::Package.trigger_services(@package.project.name, @package.name, @user.login)
    render_ok
  end

  private

  def set_package
    @package = @token.package || Package.get_by_project_and_name(params[:project], params[:package], use_source: true)
  end

  def validate_token
    @token = Token::Service.find_by(id: params[:id])
    return if @token && @token.valid_signature?(signature, request.body.read)
    render_error message: 'Token not found or not valid.', status: 403
    return false
  end

  def set_user
    @user = @token.user
  end

  # To trigger the webhook, the sender needs to
  # generate a signature with a secret token.
  # The signature needs to be generated over the
  # payload of the HTTP request and stored
  # in a HTTP header.
  # GitHub: HTTP_X_HUB_SIGNATURE
  # https://developer.github.com/webhooks/securing/
  # Pagure: HTTP_X-Pagure-Signature-256
  # https://docs.pagure.org/pagure/usage/using_webhooks.html
  # Custom signature: HTTP_X_OBS_SIGNATURE
  def signature
    request.env['HTTP_X_OBS_SIGNATURE'] ||
      request.env['HTTP_X_HUB_SIGNATURE'] ||
      request.env['HTTP_X-Pagure-Signature-256']
  end
end
