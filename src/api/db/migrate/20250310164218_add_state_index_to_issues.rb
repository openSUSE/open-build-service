class AddStateIndexToIssues < ActiveRecord::Migration[7.0]
  def change
    add_index :issues, :state
  end
end
