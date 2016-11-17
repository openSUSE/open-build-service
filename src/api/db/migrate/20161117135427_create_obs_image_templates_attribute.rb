class CreateObsImageTemplatesAttribute < ActiveRecord::Migration[5.0]
  def up
    admin = Role.find_by_title("Admin")
    namespace = AttribNamespace.first_or_create name: "OBS"
    attrib = AttribType.create( attrib_namespace: namespace, name: "ImageTemplates" )
    AttribTypeModifiableBy.create(role_id: admin.id, attrib_type_id: attrib.id)
  end

  def down
    AttribType.find_by_namespace_and_name("OBS", "ImageTemplates").delete
  end
end
