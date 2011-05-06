class DropMaintenanceReleaseDateAttribType  < ActiveRecord::Migration


  def self.up
    a = AttribType.find_by_namespace_and_name("OBS", "MaintenanceReleaseDate")
    a.destroy() unless a.nil?
  end


  def self.down
    p={}
    p[:role] = Role.find_by_title("Admin")
    ans = AttribNamespace.find_by_name "OBS"

    at=AttribType.create( :attrib_namespace => ans, :name => "MaintenanceReleaseDate" )
    at.attrib_type_modifiable_bies.create(p)
  end

end
