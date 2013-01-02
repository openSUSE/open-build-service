class CorrectRepositoriesUniqConstraint < ActiveRecord::Migration
  def up
    execute("alter table `repositories` drop index `db_project_id`;")
    execute("alter table repositories ADD UNIQUE(db_project_id,name,remote_project_name);");
  end

  def down
    execute("alter table `repositories` drop index `db_project_id`;")
    execute("alter table repositories ADD UNIQUE(db_project_id,name);");
  end
end
