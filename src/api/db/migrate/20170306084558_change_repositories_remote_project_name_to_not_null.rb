class ChangeRepositoriesRemoteProjectNameToNotNull < ActiveRecord::Migration[5.0]
  def up
    Repository.where(remote_project_name: nil).find_each do |repository|
      repository.remote_project_name = ''
      repository.save!
    end

    change_column_null :repositories, :remote_project_name, false
    change_column_default :repositories, :remote_project_name, ''
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
