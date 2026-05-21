class AddOnDeleteCascadeToValuesColumnInAttribsTable < ActiveRecord::Migration[7.0]
  def change
    # Add the new foreign key
    remove_foreign_key :attrib_values, :attribs, if_exists: true
    safety_assured do
      execute 'SET SESSION foreign_key_checks = 0'
      add_foreign_key :attrib_values, :attribs, on_delete: :cascade
      execute 'SET SESSION foreign_key_checks = 1'
    end
  end
end
