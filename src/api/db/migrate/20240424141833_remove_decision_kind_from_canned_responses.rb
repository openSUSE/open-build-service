class RemoveDecisionKindFromCannedResponses < ActiveRecord::Migration[7.0]
  def change
    safety_assured { remove_column :canned_responses, :decision_kind, :integer }
  end
end
