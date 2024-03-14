class Worker::CommandController < ApplicationController
  def run
    required_parameters :cmd, :project, :package, :repository, :arch

    unless params[:cmd] == 'checkconstraints'
      raise UnknownCommandError,
            "Unknown command '#{params[:cmd]}' for path #{request.path}"
    end

    # read permission checking
    Package.get_by_project_and_name(params[:project], params[:package], { follow_multibuild: true })

    path = '/worker'
    path += build_query_from_hash(params, %i[cmd project package repository arch])
    pass_to_backend(path)
  end
end
