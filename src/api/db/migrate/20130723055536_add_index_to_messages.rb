class AddIndexToMessages < ActiveRecord::Migration
  def change
    add_index :status_messages, [:deleted_at, :created_at]
  end
end
