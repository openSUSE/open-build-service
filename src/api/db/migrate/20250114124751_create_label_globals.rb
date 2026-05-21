class CreateLabelGlobals < ActiveRecord::Migration[7.0]
  def change
    create_table :label_globals, id: :bigint do |t|
      t.references :project, null: false, foreign_key: true, type: :integer
      t.references :label_template_global, null: false, foreign_key: true, type: :bigint

      t.timestamps
    end

    add_index :label_globals, %i[project_id label_template_global_id], unique: true, name: 'index_label_globals_on_project_and_label_template_global'
  end
end
