class AddQualityCategoryAttribType  < ActiveRecord::Migration


  def self.up
    p={}
    p[:role] = Role.find_by_title("maintainer")
    ans = AttribNamespace.find_by_name "OBS"

    at=AttribType.create( :attrib_namespace => ans, :name => "QualityCategory", :value_count=>1 )
    at.attrib_type_modifiable_bies.create(p)
    at.allowed_values << AttribAllowedValue.new( :value => "Stable" )
    at.allowed_values << AttribAllowedValue.new( :value => "Testing" )
    at.allowed_values << AttribAllowedValue.new( :value => "Development" )
    at.allowed_values << AttribAllowedValue.new( :value => "Private" )
  end


  def self.down
    AttribType.find_by_namespace_and_name("OBS", "QualityCategory").destroy()
  end

end
