class UniqRepositories < ActiveRecord::Migration
  def up
    # find broken double definitions and import current state from backend
    old = CONFIG['global_write_through']
    CONFIG['global_write_through'] = false
    transaction do
      # make it case insensitive first
      execute("ALTER TABLE `repositories` CHANGE `name` `name` VARCHAR(255) CHARACTER SET utf8 COLLATE utf8_bin NOT NULL")

      Project.find_by_sql("SELECT DISTINCT projects.* FROM repositories AS r1, repositories AS r2 LEFT JOIN projects on r2.db_project_id = projects.id WHERE ISNULL(projects.remoteurl) AND r1.db_project_id = r2.db_project_id AND r1.name = r2.name and r1.id != r2.id;").each do |prj|
        rep_ids = {}
        prj.repositories.each do |r|
          if rep_ids.has_key? r.name
            PathElement.where(repository_id: r.id).each do |pe|
              pe.repository_id = rep_ids[r.name]
              pe.save
            end
            r.destroy
          else
            rep_ids[r.name] = r.id
          end
        end
        prj.save
      end

# This fails unfortunatly with repositories in remote projects
#      execute("alter table repositories ADD UNIQUE(db_project_id,name);");
    end

    CONFIG['global_write_through'] = old
  end

  def down
    execute("alter table repositories modify name  VARCHAR(255);")
    # it makes no sense to inject broken data again
  end
end
