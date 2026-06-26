#  After some changes in Notification's database structure, some data needs to
#  be updated. But, instead of fixing the existing Notifications, we are going
#  to delete the affected ones and regenerate them with the correct values.
#
#  This data migration only performs the deletion as first step:
#
#  - Remove notifications without notifiable element. This includes
#    CommentForPackage and CommentForProject.
#  - Remove notifications with event_type values ReviewWanted, RequestCreate,
#    RequestStatechange or CommentForRequest.

class RemoveObsoleteNotifications < ActiveRecord::Migration[5.2]
  EVENTS_WITHOUT_NOTIFIABLE_TO_BE_REMOVED = [
    'Event::CommentForProject',
    'Event::CommentForPackage'
  ].freeze

  EVENTS_TO_BE_REMOVED = [
    'Event::ReviewWanted',
    'Event::RequestCreate',
    'Event::RequestStatechange',
    'Event::CommentForRequest'
  ].freeze

  def up
    delete_obsolete_notifications
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  def delete_obsolete_notifications
    Notification.where(notifiable_type: nil, notifiable_id: nil, event_type: EVENTS_WITHOUT_NOTIFIABLE_TO_BE_REMOVED).delete_all
    Notification.where(event_type: EVENTS_TO_BE_REMOVED).delete_all
  end
end
