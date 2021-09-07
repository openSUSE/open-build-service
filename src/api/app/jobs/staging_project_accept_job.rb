class StagingProjectAcceptJob < ApplicationJob
  queue_as :staging

  discard_on BsRequest::Errors::InvalidStateError

  def perform(payload)
    User.find_by!(login: payload[:user_login]).run_as do
      accept(Project.find(payload[:project_id]))
    end
  end

  def accept(staging_project)
    staging_project.send(:clear_memoized_data)
    staging_project.staged_requests.each do |staged_request|
      if staged_request.reviews.exists?(by_project: staging_project.name)
        staged_request.change_review_state(:accepted, by_project: staging_project.name, comment: "Staging Project #{staging_project.name} got accepted.")
      end
      staged_request.change_state(newstate: 'accepted', comment: "Staging Project #{staging_project.name} got accepted.")
    end
    staging_project.project_log_entries.staging_history.delete_all
  end
end
