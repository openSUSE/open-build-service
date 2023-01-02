class CreatePackageCheckUpgrades < ActiveRecord::Migration[6.1]
  def change
    create_table :package_check_upgrades, id: :integer do |t|
      t.integer :package_id
      t.string :urlsrc
      t.string :regexurl
      t.string :regexver
      t.string :currentver
      t.string :separator
      t.text :output
      t.column "state", "enum('uptodate','error','upgrade')", null: false
      t.timestamps
    end
    add_index :package_check_upgrades, :package_id
  end
end
