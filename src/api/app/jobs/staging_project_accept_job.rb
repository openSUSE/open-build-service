class StagingProjectAcceptJob < ApplicationJob
  queue_as :staging

  def perform(payload)
    current_user_before = User.current
    User.current = User.find_by(login: payload[:user_login])
    Project.find(payload[:project_id]).accept
    User.current = current_user_before
  end
end
