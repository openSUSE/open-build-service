class AddDecisionTypeToCannedResponse < ActiveRecord::Migration[7.0]
  def change
    add_column :canned_responses, :decision_type, :integer
  end
end
