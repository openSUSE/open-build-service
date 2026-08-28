class CreateDistroReleaseRepositoryArchitecture < ActiveRecord::Migration[8.1]
  def change
    create_table :distro_release_repository_architectures do |t|
      t.references :distro_release, null: false, foreign_key: true, index: false
      t.references :repository_architecture, null: false, foreign_key: true, type: :int, index: false

      t.index %i[distro_release_id repository_architecture_id], unique: true

      t.timestamps
    end
  end
end
