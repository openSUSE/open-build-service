class CreateLabelTemplates < ActiveRecord::Migration[7.0]
  def change
    create_table :label_templates, id: :bigint do |t|
      t.references :project, null: false, foreign_key: true, type: :integer
      t.string :name
      t.integer :color

      t.timestamps
    end
  end
end
