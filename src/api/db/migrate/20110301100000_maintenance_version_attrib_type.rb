class MaintenanceVersionAttribType  < ActiveRecord::Migration


  def self.up
    p={}
    p[:role] = Role.find_by_title("Admin")
    ans = AttribNamespace.find_by_name "OBS"

    at=AttribType.create( :attrib_namespace => ans, :name => "MaintenanceVersion", :value_count => 1 )
    at.attrib_type_modifiable_bies.create(p)

    atd=AttribDefaultValue.create( :attrib_type => at, :value => "_unreleased_", :position => 0 )
  end


  def self.down
    AttribType.find_by_namespace_and_name("OBS", "MaintenanceVersion").destroy()
  end

end
