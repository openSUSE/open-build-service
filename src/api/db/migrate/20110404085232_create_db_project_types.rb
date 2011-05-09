class CreateDbProjectTypes < ActiveRecord::Migration
  def self.up
    create_table :db_project_types do |t|
      t.string :name, :null => false
    end

    # Create standard content (can be done by running 'rake db:seed' too)
    DbProjectType.find_or_create_by_name("standard")
    DbProjectType.find_or_create_by_name("maintenance")
    DbProjectType.find_or_create_by_name("maintenance_incident")
  end

  def self.down
    drop_table :db_project_types
  end
end
