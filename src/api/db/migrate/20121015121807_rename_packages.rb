class RenamePackages < ActiveRecord::Migration
  def change
    rename_table :db_packages, :packages
    rename_table :db_package_issues, :package_issues
    rename_table :db_package_kinds, :package_kinds
  end
end
