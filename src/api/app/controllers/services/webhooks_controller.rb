class Services::WebhooksController < ApplicationController
  skip_before_action :extract_user
  skip_before_action :require_login
  skip_before_action :validate_params
  before_action :validate_token, :set_package, :set_user

  def create
    if !@user.is_active?
      render_error message: 'Token not found or not valid.', status: 404
      return
    end

    # identify operation type
    payload = request.body.read
    json = JSON.parse payload
    if json['action'] == 'opened'
      # pull request 
      merge_id = json['number'].to_s
      branch_params = {project: @pkg.project.name, package: @pkg.name, force: 1}
      if merge_id.present?
        branch_params[:target_project] =  User.session.home_project_name + ':MERGE:'
        branch_params[:target_project] += @pkg.project.name + ':' + @pkg.name + ':' + merge_id
      end
      ret = BranchPackage.new(branch_params).branch
      new_pkg = Package.get_by_project_and_name(ret[:data][:targetproject], ret[:data][:targetpackage])
      Backend::Connection.put(new_pkg.source_path('_branch_request'), payload)
      render_ok
    elsif json['commits'].present?
      if !@user.can_modify?(@package)
        render_error message: 'Token not found or not valid.', status: 404
        return
      end
      Backend::Api::Sources::Package.trigger_services(@package.project.name, @package.name, @user.login)
      render_ok
    end
    render_error message: 'Unhandled acton type', status: 401
  end

  private

  def set_package
    @package = @token.package || Package.get_by_project_and_name(params[:project], params[:package], use_source: true)
  end

  def validate_token
    @token = Token::Service.find_by(id: params[:id])
    return if @token && @token.valid_signature?(signature, request.body.read)

    render_error message: 'Token not found or not valid.', status: 403
    false
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
