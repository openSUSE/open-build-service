namespace :notifications do
  desc 'Backfill notified_packages for existing notifications'
  task backfill_notified_packages: :environment do
    Notification.in_batches do |batch|
      batch.each do |notification|
        package_names = NotifiedPackages.new(notification).call
        next if package_names.empty?

        NotifiedPackage.insert_all(
          package_names.map { |name| { notification_id: notification.id, package_name: name, created_at: Time.current } }
        )
      end
    end
  end
end
