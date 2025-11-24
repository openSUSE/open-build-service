class AddCascadeDeletionOnAttribDefaultValuesTableAttribTypeForeignKey < ActiveRecord::Migration[7.2]
  def change
    remove_foreign_key :attrib_default_values, :attrib_types
    add_foreign_key :attrib_default_values, :attrib_types, on_delete: :cascade, name: 'attrib_default_values_ibfk_1'
  end
end
