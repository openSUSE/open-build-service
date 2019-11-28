class CreateStagingProjectCategories < ActiveRecord::Migration[5.2]
  def change
    create_table :staging_project_categories, id: :integer do |t|
      t.references :staging_workflow, index: true, type: :integer, null: false
      t.string :title, null: false
      t.string :name_pattern, null: false
      t.timestamps
    end
  end
end
