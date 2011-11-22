class AddMaintenanceReleaseKind < ActiveRecord::Migration

  def self.up
    DbProjectType.find_or_create_by_name("maintenance_release")
  end

  def self.down
    DbProjectType.find_by_name("maintenance_release").destroy
  end

end

