class CreateStatusRepositoryPublishes < ActiveRecord::Migration[5.2]
  def change
    create_table :status_repository_publishes do |t|
      t.string :build_id
      t.belongs_to :repository, index: true
      t.timestamps
    end
  end
end
