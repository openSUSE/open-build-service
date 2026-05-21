class CreateLabelTemplateGlobals < ActiveRecord::Migration[7.0]
  def change
    create_table :label_template_globals, id: :bigint do |t|
      t.string :name, null: false
      t.string :color, null: false

      t.timestamps
    end
  end
end
