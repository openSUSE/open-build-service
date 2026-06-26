class SwitchToUtf8mb4 < ActiveRecord::Migration[5.2]
  def db
    ActiveRecord::Base.connection
  end

  def up
    execute "ALTER DATABASE `#{db.current_database}` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    db.tables.each do |table|
      execute "ALTER TABLE `#{table}` ROW_FORMAT=DYNAMIC CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    end

    execute 'ALTER TABLE `attrib_allowed_values` MODIFY `value` TEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci'
    execute 'ALTER TABLE `attrib_default_values` MODIFY `value` TEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL;'
    execute 'ALTER TABLE `attrib_values` MODIFY `value` TEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci  NOT NULL;'
    execute 'ALTER TABLE `backend_packages` MODIFY `error` TEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;'
    execute 'ALTER TABLE `bs_requests` MODIFY `description` TEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;'
    execute 'ALTER TABLE `bs_requests` MODIFY `comment` TEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;'
    execute 'ALTER TABLE `comments` MODIFY `body` TEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;'
    execute 'ALTER TABLE `configurations` MODIFY `description` TEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;'
    execute 'ALTER TABLE `delayed_jobs` MODIFY `last_error` TEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;'
    execute 'ALTER TABLE `events` MODIFY `payload` TEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;'
    execute 'ALTER TABLE `history_elements` MODIFY `comment` TEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;'
    execute 'ALTER TABLE `messages` MODIFY `text` TEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;'
    execute 'ALTER TABLE `notifications` MODIFY `event_payload` TEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL;'
    execute 'ALTER TABLE `packages` MODIFY `description` TEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;'
    execute 'ALTER TABLE `project_log_entries` MODIFY `additional_info` TEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;'
    execute 'ALTER TABLE `projects` MODIFY `description` TEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;'
    execute 'ALTER TABLE `reviews` MODIFY `reason` TEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci'
    execute 'ALTER TABLE `sessions` MODIFY `data` TEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci'
    execute 'ALTER TABLE `status_messages` MODIFY `message` TEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;'
    execute 'ALTER TABLE `users` MODIFY `adminnote` TEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;'
  end
end
