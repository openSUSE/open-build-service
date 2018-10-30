class StagingProject::StagedRequestsController < StagingProjectController
  def index
    @requests = @project.staged_requests
  end
end
