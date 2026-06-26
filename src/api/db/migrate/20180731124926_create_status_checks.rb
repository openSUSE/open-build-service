class CreateStatusChecks < ActiveRecord::Migration[5.2]
  def change
    create_table :status_checks, id: :integer, options: 'CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC' do |t|
      t.string :state
      t.string :url
      t.string :short_description
      t.string :name
      t.integer :checkable_id
      t.string  :checkable_type

      t.timestamps
    end
  end
end
