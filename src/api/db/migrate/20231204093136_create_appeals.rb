class CreateAppeals < ActiveRecord::Migration[7.0]
  def change
    create_table :appeals, id: :bigint do |t|
      t.text :reason, null: false
      t.integer :appellant_id, null: false, foreign_key: { to_table: :users }
      t.bigint :decision_id, null: false, foreign_key: true

      t.timestamps
    end
  end
end
