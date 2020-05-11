class BackfillNotifiedProjects < ActiveRecord::Migration[6.0]
  def up
    Notification.where.not(notifiable_id: nil).where.not(notifiable_type: nil).find_each do |notification|
      notification.projects << NotifiedProjects.new(notification).call
    rescue ActiveRecord::RecordNotUnique
      # We don't have to do anything...
    end
  end

  def down
    NotifiedProject.delete_all
  end
end
