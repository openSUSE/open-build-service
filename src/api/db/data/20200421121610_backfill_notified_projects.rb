class BackfillNotifiedProjects < ActiveRecord::Migration[6.0]
  def up
    Notification.where.not(notifiable_id: nil).where.not(notifiable_type: nil).find_each do |notification|
      # We cannot add the projects to be notified twice, so we need to calculate
      # the remainder of the projects that are not yet notified
      projects_to_notify = NotifiedProjects.new(notification).call
      notification.projects << (projects_to_notify - notification.projects)
    rescue ActiveRecord::RecordNotUnique
      # We don't have to do anything...
    end
  end

  def down
    NotifiedProject.delete_all
  end
end
