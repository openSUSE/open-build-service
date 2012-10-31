class RemoveDevelProject < ActiveRecord::Migration
  def up
    packs = Package.where("develproject_id is not null").all

    unless packs.empty?
      puts packs.inspect
      raise "Migrate to 2.3 first and run ./script/migrate_devel_projects"
    end
     
    execute("alter table packages drop FOREIGN KEY packages_ibfk_2")
    remove_column :packages, :develproject_id

  end

  def down
  end
end
