# We want to freely decide when we perform these changes on each OBS instance.
# That's why we opted for a task and not a data migration.
# TODO: remove this task as soon as the changes are applied to all the instances.

# Run this task with: rails dev:db:backfill_notifications_type
namespace :db do
  desc 'Backfill Notification#type according to notifiable_type'
  task backfill_notifications_type: :environment do
    Notification.find_in_batches do |batch|
      batch.each do |notification|
        case notification.notifiable_type
        when 'Report', 'Decision', 'Appeal'
          notification.update!(type: 'NotificationReport')
        else
          notification.update!(type: "Notification#{notification.notifiable_type}")
        end
      end
    end
  end
end
