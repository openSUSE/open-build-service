class FixBrokenProjectTypes < ActiveRecord::Migration
  def up
    standardid = DbProjectType.find_by_name('standard').id
    execute("update projects set type_id=#{standardid} where type_id is null")
    execute("alter table projects add foreign key (type_id) references db_project_types(id)")
    change_column :projects, :type_id, :int, null: false
  end
end
