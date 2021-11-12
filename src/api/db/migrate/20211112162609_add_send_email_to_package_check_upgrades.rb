class AddSendEmailToPackageCheckUpgrades < ActiveRecord::Migration[6.1]
  def change
    add_column :package_check_upgrades, :send_email, :boolean, default: false
  end
end
