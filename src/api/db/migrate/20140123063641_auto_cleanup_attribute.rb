class AutoCleanupAttribute < ActiveRecord::Migration
  class AttribTypeModifiableBy < ActiveRecord::Base; end

  def self.up
    role = Role.find_by_title("maintainer")
    ans = AttribNamespace.find_by_name "OBS"

    AttribTypeModifiableBy.reset_column_information

    at=AttribType.create( attrib_namespace: ans, name: "AutoCleanup", value_count: 1 )
    AttribTypeModifiableBy.create(role_id: role.id, attrib_type_id: at.id)

    add_column :configurations, :cleanup_after_days, :integer
  end

  def self.down
    AttribType.find_by_namespace_and_name("OBS", "AutoCleanup").delete()
    remove_column :configurations, :cleanup_after_days
  end
end
