class CreateDecisions < ActiveRecord::Migration[7.0]
  def change
    # Create decisions table
    create_table :decisions, id: :bigint do |t|
      t.references :moderator, null: false, foreign_key: { to_table: :users }, type: :integer

      t.text :reason, null: false
      t.integer :kind, default: 0

      t.timestamps
    end

    # Add column decision to reports table
    add_reference :reports, :decision, type: :bigint, foreign_key: { on_delete: :nullify }, index: true
  end
end
