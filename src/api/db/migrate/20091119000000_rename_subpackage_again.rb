class RenameSubpackageAgain < ActiveRecord::Migration

  def self.up
       rename_column :attribs, :binarypackage, :binary
  end

  def self.down
       rename_column :attribs, :binary, :binarypackage
  end

end
