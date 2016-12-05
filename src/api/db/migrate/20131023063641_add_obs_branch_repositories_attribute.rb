class AddObsBranchRepositoriesAttribute < ActiveRecord::Migration
  class AttribTypeModifiableBy < ActiveRecord::Base; end

  def self.up
    role = Role.find_by_title("maintainer")
    ans = AttribNamespace.find_by_name "OBS"

    at=AttribType.create( attrib_namespace: ans, name: "BranchRepositoriesFromProject", value_count: 1 )
    AttribTypeModifiableBy.create(bs_role_id: role.id, attrib_type_id: at.id)
  end

  def self.down
    AttribType.find_by_namespace_and_name("OBS", "BranchRepositoriesFromProject").destroy()
  end
end
