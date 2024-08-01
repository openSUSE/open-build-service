class CreateLabels < ActiveRecord::Migration[7.0]
  def change
    create_table :labels, id: :bigint do |t|
      t.integer :labelable_id, null: false
      t.string :labelable_type, null: false
      t.references :label_template, null: false, foreign_key: true, type: :bigint

      t.timestamps
    end

    add_index :labels, %i[labelable_type labelable_id label_template_id], unique: true, name: 'index_labels_on_labelable_and_label_template'
  end
end
