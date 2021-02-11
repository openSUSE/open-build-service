class RemoveNotificationsForMissingNotifiables < ActiveRecord::Migration[6.0]
  def up
    Notification.where(notifiable_type: 'Comment')
                .joins('LEFT OUTER JOIN comments ON notifiable_id = comments.id')
                .where(comments: { id: nil })
                .destroy_all
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
