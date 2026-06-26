class AddWorkflowTokenGroupsTable < ActiveRecord::Migration[6.1]
  def change
    create_join_table :tokens, :groups, table_name: :workflow_token_groups do |t|
      t.index :token_id
      t.index :group_id
    end
  end
end
