class CreateStatusMessages < ActiveRecord::Migration


  def self.up
    create_table :status_messages do |t|
      t.column :created_at, :timestamp
      t.column :deleted_at, :timestamp
      t.column :message, :text
      t.column :user_id, :integer
    end
    add_index :status_messages, ['user_id'], :name => "user"
  end


  def self.down
    drop_table :status_messages
  end


end
