class RenameAttribValueForeignKey < ActiveRecord::Migration
  def self.up
    rename_column :attrib_values, :attribute_id, :attrib_id

    add_column :attribs, :subpackage, :string
  end

  def self.down
    rename_column :attrib_values, :attrib_id, :attribute_id

    remove_column :attribs, :subpackage
  end
end
