class CreateStatusRepositoryPublishes < ActiveRecord::Migration[5.2]
  def change
    create_table :status_repository_publishes, id: :integer, options: 'CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC' do |t|
      t.string :build_id
      t.belongs_to :repository, type: :integer, index: true
      t.timestamps
    end
  end
end
