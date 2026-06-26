class AddTypeToDecisions < ActiveRecord::Migration[7.0]
  def change
    add_column :decisions, :type, :string, default: 'DecisionCleared', null: false
  end
end
