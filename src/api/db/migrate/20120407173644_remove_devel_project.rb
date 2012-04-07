class RemoveDevelProject < ActiveRecord::Migration
  def up
    packs = DbPackage.where("develproject_id is not null").all

    unless packs.empty?
      puts packs.inspect
      raise "Migrate to 2.3 first and run ./script/migrate_devel_projects"
    end
     
    execute("alter table db_packages drop FOREIGN KEY db_packages_ibfk_2")
    remove_column :db_packages, :develproject_id

  end

  def down
  end
end
