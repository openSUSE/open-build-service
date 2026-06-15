class AddConsecutiveAuthFailuresToTokens < ActiveRecord::Migration[7.2]
  def change
    add_column :tokens, :consecutive_auth_failures, :integer, default: 0, null: false
  end
end
