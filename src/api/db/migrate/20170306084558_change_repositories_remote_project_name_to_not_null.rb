# frozen_string_literal: true
class ChangeRepositoriesRemoteProjectNameToNotNull < ActiveRecord::Migration[5.0]
  def up
    # We need to run src/api/db/data/20170306084550_remove_duplicate_repositories.rb first,
    # otherwise we will get duplicate entry exception when we set remote_project_name to an empty string
    msg = 'Pending data migration 20170306084550. Please run rake db:migrate:with_data.'
    raise ActiveRecord::ActiveRecordError, msg unless DataMigrate::DataMigrator.get_all_versions.include?(20_170_306_084_550)
    change_column_null :repositories, :remote_project_name, false
    change_column_default :repositories, :remote_project_name, ''
  end

  def down
    change_column_null :repositories, :remote_project_name, true
    change_column_default :repositories, :remote_project_name, nil
  end
end
