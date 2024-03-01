class AddDecisionKindToCannedResponses < ActiveRecord::Migration[7.0]
  def change
    add_column :canned_responses, :decision_kind, :integer
  end
end
