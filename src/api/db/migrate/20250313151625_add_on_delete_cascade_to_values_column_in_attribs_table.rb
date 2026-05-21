class AddOnDeleteCascadeToValuesColumnInAttribsTable < ActiveRecord::Migration[7.0]
  def change
    # Add the new foreign key
    remove_foreign_key :attrib_values, :attribs, if_exists: true
    add_foreign_key :attrib_values, :attribs, on_delete: :cascade
  end
end
