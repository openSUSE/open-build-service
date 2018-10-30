class CreateStagingRequestExclusions < ActiveRecord::Migration[5.2]
  def change
    create_table :staging_request_exclusions, id: :integer, options: 'CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC' do |t|
      t.references :staging_workflow, index: true, type: :integer, null: false
      t.references :bs_request, index: true, type: :integer, null: false
      t.string :description

      t.timestamps
    end
  end
end
