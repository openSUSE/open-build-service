class RemoveDeletedAtFromStatusMessages < ActiveRecord::Migration[6.0]
  def change
    rename_index :status_messages, 'index_status_messages_on_deleted_at_and_created_at', 'index_status_messages_on_created_at'

    safety_assured { remove_column :status_messages, :deleted_at, :datetime }
  end
end
