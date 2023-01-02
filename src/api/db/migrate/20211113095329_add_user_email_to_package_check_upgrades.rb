class AddUserEmailToPackageCheckUpgrades < ActiveRecord::Migration[6.1]
  def change
    add_column :package_check_upgrades, :user_email, :string
  end
end
