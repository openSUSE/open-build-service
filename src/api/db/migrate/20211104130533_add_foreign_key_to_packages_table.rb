class AddForeignKeyToPackagesTable < ActiveRecord::Migration[6.1]
  def change
	  add_foreign_key :package_checkupgrade, :packages, name: :package_checkupgrade_ibfk_1
  end
end
