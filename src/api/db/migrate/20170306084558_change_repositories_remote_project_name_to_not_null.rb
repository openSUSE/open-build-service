class ChangeRepositoriesRemoteProjectNameToNotNull < ActiveRecord::Migration[5.0]
  def up
    execute 'UPDATE repositories SET remote_project_name = "" WHERE remote_project_name is null'

    change_column_null :repositories, :remote_project_name, false
    change_column_default :repositories, :remote_project_name, ''
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
