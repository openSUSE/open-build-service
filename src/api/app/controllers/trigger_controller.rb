class TriggerController < ApplicationController
  validate_action runservice: { method: :post, response: :status }

  #
  # This controller is checking permission always only on the base of tokens
  #
  skip_before_action :extract_user
  skip_before_action :require_login

  # github.com sends a hash payload
  skip_before_action :validate_params, only: [:runservice]
  before_action :receive_token
  before_action :set_package

  def runservice
    return unless @pkg
    # execute the service in backend
    path = @pkg.source_path
    params = { cmd: 'runservice', comment: 'runservice via trigger', user: @token.user.login }
    path << build_query_from_hash(params, [:cmd, :comment, :user])
    pass_to_backend(path)

    @pkg.sources_changed
  end

  private

  def receive_token
    auth = request.env['HTTP_AUTHORIZATION']

    if request.env['HTTP_X_GITLAB_EVENT'] == 'Push Hook'
      auth = 'Token ' + request.env['HTTP_X_GITLAB_TOKEN']
    end

    unless auth && auth[0..4] == 'Token' && auth[6..-1] =~ /^[A-Za-z0-9+\/]+$/
      render_error errorcode: 'permission_denied',
                   message: "No valid token found 'Authorization' header",
                   status: 403
      return
    end

    @token = Token::Service.find_by_string(auth[6..-1])

    return if @token
    render_error message: 'Token not found', status: 404
  end

  def set_package
    return unless @token
    @pkg = @token.package
    @pkg ||= Package.get_by_project_and_name(params[:project].to_s, params[:package].to_s, use_source: true)
    unless @pkg
      render_error errorcode: 'not_found',
                   message: 'package or project not specified or does not exist',
                   status: 404
      return
    end

    # check if user has still access
    return if @token.user.is_active? && @token.user.can_modify?(@pkg)
    render_error message: "no permission for package #{@pkg.name} in project #{@pkg.project.name}",
                 status: 403,
                 errorcode: 'no_permission'
  end
end
