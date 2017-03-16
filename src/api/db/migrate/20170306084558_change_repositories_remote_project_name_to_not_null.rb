class ChangeRepositoriesRemoteProjectNameToNotNull < ActiveRecord::Migration[5.0]
  def up
    transaction do
      execute 'UPDATE repositories SET remote_project_name = "" WHERE remote_project_name is null'
      # drop existsing double entries, must be a ruby loop for the path_elements and reference cleanup
      Repository.find_by_sql("select A.* from repositories as A  LEFT JOIN repositories as B ON A.db_project_id = B.db_project_id and A.name = B.name where A.id != B.id").each.destroy

      change_column_null :repositories, :remote_project_name, false
      change_column_default :repositories, :remote_project_name, ''
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
