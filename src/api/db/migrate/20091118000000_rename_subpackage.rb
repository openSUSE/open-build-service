class RenameSubpackage < ActiveRecord::Migration

  def self.up
       rename_column :attribs, :subpackage, :binarypackage
  end

  def self.down
       rename_column :attribs, :binarypackage, :subpackage
  end

end
