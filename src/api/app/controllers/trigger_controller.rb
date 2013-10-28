class TriggerController < ApplicationController

  validate_action :runservice => {:method => :post, :response => :status}
  skip_before_action :extract_user

  def runservice
    auth = request.env['HTTP_AUTHORIZATION']
    unless auth and auth[0..4] == "Token"
      render_error errorcode: 'permission_denied',
                   message: "No valid token found 'Authorization' header",
                   status: 403
      return
    end

    token = Token.find_by_string auth[6..-1]

    unless token
      render_error  message: "Token not found", :status => 404
      return
    end

    pkg = token.package
    unless pkg
      # token is not bound to a package, but event may have specified it
      pkg = Package.get_by_project_and_name(request.env['HTTP_PROJECT'], request.env['HTTP_PACKAGE'], use_source: true)
      unless token.user.can_modify_package? pkg
	raise NoPermission.new "no permission for package #{pkg.name} in project #{pkg.project.name}"
      end
    end

    # execute the service in backend
    path = pkg.source_path
    params = { :cmd => "runservice", :comment => "runservice via trigger", :user => token.user.login }
    path << build_query_from_hash(params, [:cmd, :comment, :user])
    pass_to_backend path

    pkg.sources_changed

  end
  
end
