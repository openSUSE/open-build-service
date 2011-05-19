class CreateDbProjectTypesEntries < ActiveRecord::Migration
  def self.up
    # Create standard content (can be done by running 'rake db:seed' too)
    DbProjectType.find_or_create_by_name("standard")
    DbProjectType.find_or_create_by_name("maintenance")
    DbProjectType.find_or_create_by_name("maintenance_incident")
  end

  def self.down
  end
end
