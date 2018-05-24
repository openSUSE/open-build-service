class AddCollateToAllTables < ActiveRecord::Migration[5.1]
  def up
    ['product_update_repositories', 'packages', 'package_issues', 'notifications', 'maintained_projects', 'kiwi_repositories',
     'kiwi_preferences', 'kiwi_packages', 'kiwi_package_groups', 'kiwi_images', 'incident_updateinfo_counter_values',
     'groups_roles', 'flags', 'delayed_jobs', 'cloud_user_upload_jobs', 'cloud_ec2_configurations', 'bs_request_actions',
     'attribs', 'ar_internal_metadata'].each do |table|
      execute("ALTER TABLE #{table} CONVERT TO CHARACTER SET utf8 COLLATE utf8_bin")
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
