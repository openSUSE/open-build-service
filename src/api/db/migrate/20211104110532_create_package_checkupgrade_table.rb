class CreatePackageCheckupgradeTable < ActiveRecord::Migration[6.1]
  def change
    create_table :package_checkupgrade, id: :integer do |t|
      t.integer :package_id, null: false
      t.string :urlsrc, null: false
      t.string :regexurl, null: false
      t.string :regexver, null: false
      t.string :currentver, null: false
      t.string :separator, null: false
      t.text   :output
      t.column "state", "enum('uptodate','error','upgrade')", null: false
      t.timestamps
    end
  end
end
