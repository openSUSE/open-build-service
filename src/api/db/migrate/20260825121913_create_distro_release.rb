class CreateDistroRelease < ActiveRecord::Migration[8.1]
  def change
    create_table :distro_releases do |t|
      t.references :distro, null: false, foreign_key: true, index: false
      t.string :name
      t.text :description
      t.string :url

      t.index %i[distro_id name], unique: true

      t.timestamps
    end
  end
end
