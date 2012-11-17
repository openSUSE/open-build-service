class AddBugownerRootProjectAttribType  < ActiveRecord::Migration

  def self.up
    p={}
    p[:role] = Role.find_by_title("Admin")
    ans = AttribNamespace.find_by_name "OBS"

    self.transaction do
      at=AttribType.create( :attrib_namespace => ans, :name => "BugownerRootProject" )
      at.attrib_type_modifiable_bies.create(p)
      at.allowed_values << AttribAllowedValue.new( :value => "DisableDevel" )
      at.allowed_values << AttribAllowedValue.new( :value => "BugownerOnly" )
    end
  end

  def self.down
    AttribType.find_by_namespace_and_name("OBS", "BugownerRootProject").destroy()
  end

end
