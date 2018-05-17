class ChangeDefaultCharsetAndMysql57Defaults < ActiveRecord::Migration[5.1]
  # mysql/mariadb has changed the default to utf8mb4, we need to update old instances
  # to avoid to have specific sql code for difference mysql versions
  def up
    # these may be utf8 or utf8mb4 depending on the use mysql instance on creation time
#    [ 'ar_internal_metadata', 'binary_releases', 'bs_request_counter',
#      'cloud_azure_configurations', 'cloud_ec2_configurations', 
#      'cloud_user_upload_jobs', 'data_migrations', 'download_repositories',
#      'group_maintainers', 'incident_updateinfo_counter_values',
#      'kiwi_images', 'kiwi_package_groups', 'kiwi_packages',
#      'kiwi_preferences', 'kiwi_repositories', 'maintained_projects',
#      'product_media', 'product_update_repositories' ].each do |table|
#      execute("ALTER TABLE #{table} CONVERT TO CHARACTER SET utf8");
#    end
    # contains free text, could have emojis
    [ 'configurations', 'history_elements', 'kiwi_descriptions', 'notifications' ].each do |table|
      execute("ALTER TABLE #{table} ROW_FORMAT=DYNAMIC"); # default in MySQL 5.7 & MariaDB 10.2
      execute("ALTER TABLE #{table} CONVERT TO CHARACTER SET utf8mb4");
    end
    # these got reduced on utf8mb4 convert
    execute('alter table configurations modify description mediumtext DEFAULT NULL;')
    execute('alter table history_elements modify comment mediumtext DEFAULT NULL;')
    execute('alter table notifications modify event_payload mediumtext NOT NULL;')
  end

  def down
    # Not reversible since it depends which database version was used on creation
    # time. You may just skip this by removing the raise
    raise ActiveRecord::IrreversibleMigration
    # or set it to the old default. You may loose some chars in free text when
    # it was used in production and people used emojis or alike
#    [ 'ar_internal_metadata', 'binary_releases', 'bs_request_counter',
#      'cloud_azure_configurations', 'cloud_ec2_configurations', 
#      'cloud_user_upload_jobs', 'configurations', 'data_migrations', 'download_repositories',
#      'group_maintainers', 'history_elements', 'incident_updateinfo_counter_values',
#      'kiwi_descriptions', 'kiwi_images', 'kiwi_package_groups', 'kiwi_packages',
#      'kiwi_preferences', 'kiwi_repositories', 'maintained_projects',
#      'notifications', 'product_media', 'product_update_repositories' ].each do |table|
#      execute("ALTER TABLE #{table} CONVERT TO CHARACTER SET utf8");
#    end
  end
end
