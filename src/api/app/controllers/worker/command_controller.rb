class Worker::CommandController < ApplicationController
  def run
    required_parameters :cmd, :project, :package, :repository, :arch

    raise UnknownCommandError, "Unknown command '#{params[:cmd]}' for path #{request.path}" unless params[:cmd] == 'checkconstraints'

    # read permission checking
    Package.get_by_project_and_name(params[:project], params[:package])

    path = '/worker'
    path += build_query_from_hash(params, [:cmd, :project, :package, :repository, :arch])
    pass_to_backend(path)
  end
end
