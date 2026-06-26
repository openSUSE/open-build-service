class AddMissingForeignKeyConstraintsToAppeals < ActiveRecord::Migration[7.0]
  def change
    safety_assured do
      execute 'SET SESSION foreign_key_checks = 0'
      add_foreign_key :appeals, :users, column: :appellant_id, primary_key: :id
      add_foreign_key :appeals, :decisions, column: :decision_id, primary_key: :id
      execute 'SET SESSION foreign_key_checks = 1'
    end
  end
end
