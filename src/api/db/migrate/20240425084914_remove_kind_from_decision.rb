class RemoveKindFromDecision < ActiveRecord::Migration[7.0]
  def change
    safety_assured { remove_column :decisions, :kind, :integer }
  end
end
