class ChangeAttribNamespaceModifiableBiesForeignKeyOnAttribNamespaceToOnDeleteCascade < ActiveRecord::Migration[7.2]
  def change
    remove_foreign_key :attrib_namespace_modifiable_bies, :attrib_namespaces, if_exists: true
    add_foreign_key :attrib_namespace_modifiable_bies, :attrib_namespaces, name: 'attrib_namespace_modifiable_bies_ibfk_1', on_delete: :cascade
  end
end
