class AddAllowedBranchesToTokens < ActiveRecord::Migration[7.2]
  def change
    add_column :tokens, :allowed_branches, :text
  end
end
