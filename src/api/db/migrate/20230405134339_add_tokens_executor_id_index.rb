class AddTokensExecutorIdIndex < ActiveRecord::Migration[7.0]
  def change
    add_index :tokens, %w[executor_id], name: :index_tokens_executor_id, unique: true
  end
end
