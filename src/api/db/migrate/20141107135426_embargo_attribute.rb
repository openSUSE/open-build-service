
require_relative '../attribute_descriptions'

class EmbargoAttribute < ActiveRecord::Migration
  class AttribTypeModifiableBy < ActiveRecord::Base; end

  def self.up
    ans = AttribNamespace.find_by_name "OBS"

    AttribTypeModifiableBy.reset_column_information

    at=AttribType.create( attrib_namespace: ans, name: "EmbargoDate", value_count: 1 )

    role = Role.find_by_title("maintainer")
    AttribTypeModifiableBy.create(role_id: role.id, attrib_type_id: at.id)

    update_all_attrib_type_descriptions
  end

  def self.down
    AttribType.find_by_namespace_and_name("OBS", "EmbargoDate").delete()
  end
end
