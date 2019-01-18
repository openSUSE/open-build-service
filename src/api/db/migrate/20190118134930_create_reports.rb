class CreateReports < ActiveRecord::Migration[5.2]
  def change
    create_table :reports, id: :integer do |t|
      t.string :type
      t.boolean :dismissed, default: false
      t.text :failure_message
      t.references :staging_project, type: :integer

      t.timestamps
    end
  end
end
