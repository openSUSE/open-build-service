class AddWorkflowTokenUsersTable < ActiveRecord::Migration[6.1]
  def change
    create_join_table :tokens, :users, table_name: :workflow_token_users do |t|
      t.index :token_id
      t.index :user_id
    end
  end
end
