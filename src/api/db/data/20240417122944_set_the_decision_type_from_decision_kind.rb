# frozen_string_literal: true

class SetTheDecisionTypeFromDecisionKind < ActiveRecord::Migration[7.0]
  def up
    return unless Decision.columns.any? { |c| c.name == 'kind' }

    Decision.in_batches do |batch|
      batch.each do |decision|
        decision.type = decision.favor? ? 'DecisionFavored' : 'DecisionCleared'
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
