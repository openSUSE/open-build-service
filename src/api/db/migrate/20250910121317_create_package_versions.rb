class CreatePackageVersions < ActiveRecord::Migration[7.2]
  def change
    create_table :package_versions, id: :bigint do |t|
      t.references :package, null: false, foreign_key: true, type: :integer
      t.string :version, null: false
      t.string :type, null: false

      t.timestamps
    end
  end
end
