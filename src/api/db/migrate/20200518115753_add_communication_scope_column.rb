class AddCommunicationScopeColumn < ActiveRecord::Migration[6.0]
  def up
    add_column :status_messages, :communication_scope, :integer
    change_column_default :status_messages, :communication_scope, 0
    # NOTE: Temporarily duplication in Announcement table, which is going to be dropped soon.
    add_column :announcements, :communication_scope, :integer
    change_column_default :announcements, :communication_scope, 0
  end

  def down
    remove_column :status_messages, :communication_scope
    remove_column :announcements, :communication_scope
  end
end
