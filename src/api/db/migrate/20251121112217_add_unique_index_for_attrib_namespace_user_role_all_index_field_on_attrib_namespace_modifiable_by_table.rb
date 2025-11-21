class AddUniqueIndexForAttribNamespaceUserRoleAllIndexFieldOnAttribNamespaceModifiableByTable < ActiveRecord::Migration[7.2]
  def change
    add_unique_index :attrib_namespace_modifiable_bies, :attrib_namespace_user_role_all_index
  end
end
