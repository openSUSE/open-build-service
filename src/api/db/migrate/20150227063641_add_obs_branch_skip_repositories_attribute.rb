require_relative '../attribute_descriptions'

class AddObsBranchSkipRepositoriesAttribute < ActiveRecord::Migration
  class AttribTypeModifiableBy < ActiveRecord::Base; end

  def self.up
    role = Role.find_by_title("maintainer")
    ans = AttribNamespace.find_by_name "OBS"

    at=AttribType.create( attrib_namespace: ans, name: "BranchSkipRepositories" )
    AttribTypeModifiableBy.create(role_id: role.id, attrib_type_id: at.id)

    update_all_attrib_type_descriptions
  end

  def self.down
    AttribType.find_by_namespace_and_name("OBS", "BranchSkipRepositories").destroy()
  end
end
