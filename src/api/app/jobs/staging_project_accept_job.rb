# typed: true
class StagingProjectAcceptJob < ApplicationJob
  queue_as :staging

  def perform(payload)
    User.find_by!(login: payload[:user_login]).run_as do
      accept(Project.find(payload[:project_id]))
    end
  end

  def accept(staging_project)
    staging_project.send(:clear_memoized_data)
    return unless staging_project.overall_state.in?([:accepting, :acceptable])
    accepted_packages = []
    staging_project.staged_requests.each do |staged_request|
      if staged_request.reviews.where(by_project: staging_project.name).exists?
        staged_request.change_review_state(:accepted, by_project: staging_project.name, comment: "Staging Project #{staging_project.name} got accepted.")
      end
      staged_request.change_state(newstate: 'accepted', comment: "Staging Project #{staging_project.name} got accepted.")
      accepted_packages.concat(staged_request.bs_request_actions.map(&:target_package))
    end
    staging_project.packages.where(name: accepted_packages).find_each(&:destroy)
    staging_project.staged_requests.delete_all
  end
end
