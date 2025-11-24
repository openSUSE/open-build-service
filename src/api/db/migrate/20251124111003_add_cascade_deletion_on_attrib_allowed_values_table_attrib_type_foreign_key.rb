class AddCascadeDeletionOnAttribAllowedValuesTableAttribTypeForeignKey < ActiveRecord::Migration[7.2]
  def change
    remove_foreign_key :attrib_allowed_values, :attrib_types
    add_foreign_key :attrib_allowed_values, :attrib_types, on_delete: :cascade, name: 'attrib_allowed_values_ibfk_1'
  end
end
