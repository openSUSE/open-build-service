class StagingProjectAcceptJob < ApplicationJob
  queue_as :staging

  discard_on BsRequest::Errors::InvalidStateError

  def perform(payload)
    User.find_by!(login: payload[:user_login]).run_as do
      staging_project = Project.find(payload[:project_id])
      staging_project.accept
    end
  end
end
