class RemoveDuplicateRepositories < ActiveRecord::Migration[5.1]
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
        AND a.remote_project_name IS NULL
        AND b.remote_project_name IS NULL
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
          AND a.remote_project_name IS NULL
          AND b.remote_project_name IS NULL
          AND a.id IN (#{repos_with_duplicates.map(&:id).join(', ')})
        SQL

        duplicate_repos = Repository.find_by_sql(sql)
        # We simply destroy the duplicate repository
        # A full migration is not possible and does not make sense
        # as it would probably corrupt even more data
        # Because of that it must be a ruby loop for the path_elements and reference cleanup
        duplicate_repos.each(&:destroy)
      end
    end

    execute('UPDATE repositories SET remote_project_name = "" WHERE remote_project_name is null')
    CONFIG['global_write_through'] = old
    nil # rails migrations return nil
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
