class AddEnabledIndexToTokens < ActiveRecord::Migration[7.0]
  def change
    add_index(:tokens, :enabled)
  end
end
