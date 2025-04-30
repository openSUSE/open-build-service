class CreateAssignments < ActiveRecord::Migration[7.1]
  def change
    create_table :assignments do |t|
      t.references :assignee, null: false, foreign_key: { to_table: :users }, type: :integer
      t.references :assigner, null: false, foreign_key: { to_table: :users }, type: :integer
      t.references :package, null: false, foreign_key: true, type: :integer, index: false

      t.index [:package_id], unique: true
      t.timestamps
    end
  end
end
