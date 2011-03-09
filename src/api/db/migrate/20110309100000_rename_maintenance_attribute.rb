class RenameMaintenanceAttribute  < ActiveRecord::Migration

  def self.up
    AttribType.find_by_namespace_and_name("OBS", "Maintenance").destroy()

    p={}
    p[:role] = Role.find_by_title("Admin")
    ans = AttribNamespace.find_by_name "OBS"

    at=AttribType.create( :attrib_namespace => ans, :name => "MaintenanceProject", :value_count=>0 )
    at.attrib_type_modifiable_bies.create(p)
  end


  def self.down
    AttribType.find_by_namespace_and_name("OBS", "MaintenanceProject").destroy()

    p={}
    p[:role] = Role.find_by_title("Admin")
    ans = AttribNamespace.find_by_name "OBS"

    at=AttribType.create( :attrib_namespace => ans, :name => "Maintenance", :value_count=>0 )
    at.attrib_type_modifiable_bies.create(p)
  end

end
