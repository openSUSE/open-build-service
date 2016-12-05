class AddOwnerRootProjectAttribType < ActiveRecord::Migration
  def self.up
    p={}
    p[:role] = Role.find_by_title("Admin")
    ans = AttribNamespace.find_by_name "OBS"

    transaction do
      at=AttribType.create( attrib_namespace: ans, name: "OwnerRootProject" )
      at.attrib_type_modifiable_bies.create(p)
      at.allowed_values << AttribAllowedValue.new( value: "DisableDevel" )
      at.allowed_values << AttribAllowedValue.new( value: "BugownerOnly" )
    end
  end

  def self.down
    AttribType.find_by_namespace_and_name("OBS", "OwnerRootProject").destroy()
  end
end
