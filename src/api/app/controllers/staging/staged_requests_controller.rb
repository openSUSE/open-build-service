class Staging::StagedRequestsController < Staging::ProjectsController
  def index
    @requests = @project.staged_requests
  end
end
