class CorrectRepositoriesUniqConstraint < ActiveRecord::Migration
  def up
    execute("alter table repositories ADD UNIQUE(db_project_id,name,remote_project_name);");
    execute("alter table `repositories` drop index `db_project_id`;")
  end

  def down
    execute("alter table repositories ADD UNIQUE(db_project_id,name);");
    execute("alter table `repositories` drop index `projects_name_index`;")
  end
end
