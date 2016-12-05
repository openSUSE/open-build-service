class AttributeIssueMarker < ActiveRecord::Migration
  def self.up
    ans = AttribNamespace.find_by_name "OBS"

    at=AttribType.create( attrib_namespace: ans, name: "Issues", value_count: 0 )
    p={}
    p[:bs_role_id] = Role.find_by_title("maintainer").id
    at.attrib_type_modifiable_bies.create(p)
    p[:bs_role_id] = Role.find_by_title("bugowner").id
    at.attrib_type_modifiable_bies.create(p)
    p[:bs_role_id] = Role.find_by_title("reviewer").id
    at.attrib_type_modifiable_bies.create(p)
  end

  def self.down
    a = AttribType.find_by_namespace_and_name("OBS", "Issues")
    a.delete unless a.nil?
  end
end
