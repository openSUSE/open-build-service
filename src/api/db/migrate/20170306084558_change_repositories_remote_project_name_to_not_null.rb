class ChangeRepositoriesRemoteProjectNameToNotNull < ActiveRecord::Migration[5.0]
  def up
    execute "ALTER TABLE `repositories` CHANGE  `remote_project_name` `remote_project_name` varchar(255) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL DEFAULT ''"
  end

  def down
    execute 'ALTER TABLE `repositories` CHANGE  `remote_project_name` `remote_project_name` varchar(255) CHARACTER SET utf8 COLLATE utf8_bin DEFAULT NULL'
  end
end
