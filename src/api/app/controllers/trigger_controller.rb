class TriggerController < ApplicationController
  validate_action runservice: { method: :post, response: :status }

  #
  # This controller is checking permission always only on the base of tokens
  #
  skip_before_action :extract_user
  skip_before_action :require_login

  # github.com sends a hash payload
  skip_before_action :validate_params, only: [:runservice]

  def runservice
    auth = request.env['HTTP_AUTHORIZATION']
    unless auth && auth[0..4] == 'Token' && auth[6..-1] =~ /^[A-Za-z0-9+\/]+$/
      render_error errorcode: 'permission_denied',
                   message: "No valid token found 'Authorization' header",
                   status: 403
      return
    end

    token = Token::Service.find_by_string(auth[6..-1])

    unless token
      render_error message: 'Token not found', status: 404
      return
    end

    pkg = token.package || Package.get_by_project_and_name(params[:project].to_s, params[:package].to_s, use_source: true)
    if pkg
      # check if user has still access
      unless token.user.is_active? && token.user.can_modify_package?(pkg)
        render_error message:   "no permission for package #{pkg.name} in project #{pkg.project.name}",
                     status:    403,
                     errorcode: 'no_permission'
        return
      end
    end

    # execute the service in backend
    path = pkg.source_path
    params = { cmd: 'runservice', comment: 'runservice via trigger', user: token.user.login }
    path << build_query_from_hash(params, [:cmd, :comment, :user])
    pass_to_backend path

    pkg.sources_changed
  end
end
