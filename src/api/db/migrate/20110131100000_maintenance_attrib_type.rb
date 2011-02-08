class MaintenanceAttribType  < ActiveRecord::Migration


  def self.up
    p={}
    p[:role] = Role.find_by_title("Admin")
    ans = AttribNamespace.find_by_name "OBS"

    at=AttribType.create( :attrib_namespace => ans, :name => "Maintenance", :value_count=>0 )
    at.attrib_type_modifiable_bies.create(p)
  end


  def self.down
    AttribType.find_by_namespace_and_name("OBS", "Maintenance").destroy()
  end

end
