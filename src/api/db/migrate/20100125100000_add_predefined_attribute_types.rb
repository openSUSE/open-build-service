class AddPredefinedAttributeTypes  < ActiveRecord::Migration


  def self.up
    # set owner ship to Admin, but actually not even the Admin should change these
    p={}
    p[:user] = User.find_by_login("Admin")
    ans = AttribNamespace.create :name => "OBS"
    ans.attrib_namespace_modifiable_bies.create(p)

    at=AttribType.create( :attrib_namespace => ans, :name => "VeryImportantProject", :value_count=>0 )
    at.attrib_type_modifiable_bies.create(p)
    at=AttribType.create( :attrib_namespace => ans, :name => "UpdateProject", :value_count=>1 )
    at.attrib_type_modifiable_bies.create(p)
    at=AttribType.create( :attrib_namespace => ans, :name => "ScreenShots" )
    at.attrib_type_modifiable_bies.create(p)
    at=AttribType.create( :attrib_namespace => ans, :name => "Maintained", :value_count=>0 )
    at.attrib_type_modifiable_bies.create(p)
  end


  def self.down
    AttribNamespace.find_by_name("OBS").destroy()
  end

end
