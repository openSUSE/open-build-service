# frozen_string_literal: true

class BackfillDecisionTypeInCannedResponses < ActiveRecord::Migration[7.0]
  def up
    CannedResponse.where.not(decision_kind: nil).find_each do |canned_response|
      canned_response.update(decision_type: CannedResponse.decision_kinds[canned_response[:decision_kind]])
    end
  end

  def down
    # rubocop:disable Rails/SkipsModelValidations
    CannedResponse.where.not(decision_type: nil).in_batches.update_all(decision_type: nil)
    # rubocop:enable Rails/SkipsModelValidations
  end
end
