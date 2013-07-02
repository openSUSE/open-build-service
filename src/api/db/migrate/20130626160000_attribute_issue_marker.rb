class AttributeIssueMarker  < ActiveRecord::Migration

  def self.up

    ans = AttribNamespace.find_by_name "OBS"

    at=AttribType.create( :attrib_namespace => ans, :name => "Issues",  :value_count => 0 )
    p={}
    p[:role] = Role.find_by_title("maintainer")
    at.attrib_type_modifiable_bies.create(p)
    p[:role] = Role.find_by_title("bugowner")
    at.attrib_type_modifiable_bies.create(p)
    p[:role] = Role.find_by_title("reviewer")
    at.attrib_type_modifiable_bies.create(p)
  end


  def self.down
    a = AttribType.find_by_namespace_and_name("OBS", "Issues")
    a.delete unless a.nil?
  end

end
