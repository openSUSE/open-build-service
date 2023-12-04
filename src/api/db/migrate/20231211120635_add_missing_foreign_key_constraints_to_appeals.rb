class AddMissingForeignKeyConstraintsToAppeals < ActiveRecord::Migration[7.0]
  def change
    add_foreign_key :appeals, :users, column: :appellant_id, primary_key: :id
    add_foreign_key :appeals, :decisions, column: :decision_id, primary_key: :id
  end
end
