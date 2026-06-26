class Worker::CommandController < ApplicationController
  def run
    params.require(%i[project package repository arch])

    # read permission checking
    Package.get_by_project_and_name(params[:project], params[:package], { follow_multibuild: true })

    render xml: Backend::Api::Worker.check_constraints(params.slice(:project, :package, :repository, :arch).permit!.to_h,
                                                       request.body.string.presence || '<constraints></constraints>')
  end
end
