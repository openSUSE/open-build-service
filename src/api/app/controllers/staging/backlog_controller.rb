class Staging::BacklogController < Staging::StagingController
  before_action :require_login, except: [:index]
  before_action :set_project
  before_action :set_staging_workflow

  def index
    @backlog = @staging_workflow.unassigned_requests
  end
end
