class CreateDistroReleaseLifecycles < ActiveRecord::Migration[8.1]
  def change
    create_table :distro_release_lifecycles do |t|
      t.references :distro_release, null: false, foreign_key: true, index: false
      t.string :name, null: false
      t.date :date, null: false
      t.integer :status, default: 0, null: false

      t.index %i[distro_release_id name], unique: true

      t.timestamps
    end
  end
end
