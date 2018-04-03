class RevertChangeRepositoriesRemoteProjectNameToNotNull < ActiveRecord::Migration[5.0]
  # this reverts a harmful migration which was only temporarly available during OBS 2.9 development.
  # it is a NOOP if it that one got not applied
  def up
    old = CONFIG['global_write_through']
    CONFIG['global_write_through'] = false

    Repository.transaction do
      execute 'UPDATE repositories SET remote_project_name = NULL WHERE remote_project_name = ""'
      change_column_default :repositories, :remote_project_name, NULL
      change_column_null :repositories, :remote_project_name, true
    end

    CONFIG['global_write_through'] = old
  end

  def down
    old = CONFIG['global_write_through']
    CONFIG['global_write_through'] = false

    Repository.transaction do
      execute 'UPDATE repositories SET remote_project_name = "" WHERE remote_project_name is NULL'
      change_column_default :repositories, :remote_project_name, ''
      change_column_null :repositories, :remote_project_name, false
    end

    CONFIG['global_write_through'] = old
  end
end
