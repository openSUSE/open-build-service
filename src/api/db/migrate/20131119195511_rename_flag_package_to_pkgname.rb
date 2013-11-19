class RenameFlagPackageToPkgname < ActiveRecord::Migration
  def self.up
    rename_column :flags, :package, :pkgname
    Flag.reset_column_information
  end

  def self.down
    rename_column :flags, :pkgname, :package
    Flag.reset_column_information
  end
end
