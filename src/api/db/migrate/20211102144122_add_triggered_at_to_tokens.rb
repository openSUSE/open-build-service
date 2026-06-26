class AddTriggeredAtToTokens < ActiveRecord::Migration[6.1]
  def change
    add_column :tokens, :triggered_at, :datetime
  end
end
