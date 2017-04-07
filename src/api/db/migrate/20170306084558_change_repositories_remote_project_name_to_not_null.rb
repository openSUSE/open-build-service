class ChangeRepositoriesRemoteProjectNameToNotNull < ActiveRecord::Migration[5.0]
  def up
    old = CONFIG['global_write_through']
    CONFIG['global_write_through'] = false

    Repository.transaction do
      sql = <<-SQL
        SELECT a.*
        FROM repositories AS a
        LEFT JOIN repositories AS b
        ON a.db_project_id = b.db_project_id
        AND a.name = b.name
        WHERE a.id != b.id
        GROUP BY a.db_project_id, a.name
      SQL

      repos_with_duplicates = Repository.find_by_sql(sql)

      if repos_with_duplicates.any?
        sql = <<-SQL
          SELECT b.*
          FROM repositories a
          LEFT JOIN repositories AS b
          ON a.db_project_id = b.db_project_id
          AND a.name = b.name
          WHERE a.id != b.id
          AND a.id IN (#{repos_with_duplicates.map(&:id).join(', ')})
        SQL

        duplicate_repos = Repository.find_by_sql(sql)

        # must be a ruby loop for the path_elements and reference cleanup
        duplicate_repos.each(&:destroy)
      end

      execute 'UPDATE repositories SET remote_project_name = "" WHERE remote_project_name is null'

      change_column_null :repositories, :remote_project_name, false
      change_column_default :repositories, :remote_project_name, ''
    end

    CONFIG['global_write_through'] = old
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
