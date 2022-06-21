class AddExecutorColumnToTokensTable < ActiveRecord::Migration[6.1]
  def change
    add_column :tokens, :executor_id, :integer, null: false, default: 0
    add_index :tokens, :executor_id
  end
end
