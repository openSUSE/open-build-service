class AddCommunicationScopeToStatusMessage < ActiveRecord::Migration[6.0]
  def up
    add_column :status_messages, :communication_scope, :integer
    change_column_default :status_messages, :communication_scope, 0
  end

  def down
    remove_column :status_messages, :communication_scope
  end
end
