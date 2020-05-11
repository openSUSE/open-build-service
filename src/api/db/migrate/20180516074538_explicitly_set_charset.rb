class ExplicitlySetCharset < ActiveRecord::Migration[5.1]
  def up
    [
      'product_update_repositories', 'kiwi_repositories', 'kiwi_preferences', 'kiwi_packages',
      'kiwi_package_groups', 'incident_updateinfo_counter_values', 'cloud_user_upload_jobs',
      'kiwi_images', 'cloud_ec2_configurations', 'ar_internal_metadata', 'maintained_projects',
      'data_migrations', 'binary_releases', 'cloud_azure_configurations', 'download_repositories',
      'group_maintainers', 'history_elements', 'kiwi_descriptions', 'notifications', 'product_media',
      'bs_request_counter'
    ].each do |table|
      execute("ALTER TABLE #{table} CONVERT TO CHARACTER SET utf8")
    end

    ['delayed_jobs', 'flags'].each do |table|
      execute("ALTER TABLE #{table} CONVERT TO CHARACTER SET utf8 COLLATE utf8_bin")
    end

    change_column(:delayed_jobs, :last_error, 'TEXT CHARACTER SET utf8')
    change_column(:delayed_jobs, :locked_by, 'varchar(255) CHARACTER SET utf8 DEFAULT NULL')
    change_column(:delayed_jobs, :queue, 'varchar(255) CHARACTER SET utf8 DEFAULT NULL')

    change_column(:flags, :status, "ENUM('enable','disable') CHARACTER SET utf8 NOT NULL")
    change_column(:flags, :repo, 'varchar(255) CHARACTER SET utf8 DEFAULT NULL')
    change_column(:flags, :flag, "ENUM('useforbuild','sourceaccess','binarydownload','debuginfo','build','publish','access','lock')" \
                                 ' CHARACTER SET utf8 NOT NULL')
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
