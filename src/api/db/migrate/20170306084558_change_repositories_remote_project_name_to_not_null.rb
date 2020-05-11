class ChangeRepositoriesRemoteProjectNameToNotNull < ActiveRecord::Migration[5.0]
  def up
    # We need to run src/api/db/data/20170306084550_remove_duplicate_repositories.rb first,
    # otherwise we will get duplicate entry exception when we set remote_project_name to an empty string
    msg = 'Pending data migration 20170306084550. Please run rake db:migrate:with_data.'
    raise ActiveRecord::ActiveRecordError, msg unless DataMigrate::DataSchemaMigration.where(version: 20_170_306_084_550).exists?
    execute "ALTER TABLE `repositories` CHANGE  `remote_project_name` `remote_project_name` varchar(255) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL DEFAULT ''"
  end

  def down
    execute 'ALTER TABLE `repositories` CHANGE  `remote_project_name` `remote_project_name` varchar(255) CHARACTER SET utf8 COLLATE utf8_bin DEFAULT NULL'
  end
end
