class CreateMessages < ActiveRecord::Migration


  def self.up
    create_table :messages do |t|
      t.column :object_id, :integer
      t.column :object_type, :string
      t.column :user_id, :integer
      t.column :created_at, :timestamp
      t.column :send_mail, :boolean
      t.column :sent_at, :timestamp
      t.column :private, :boolean
      t.column :severity, :integer
      t.column :text, :text
    end
    add_index :messages, ['object_id'], :name => "object"
    add_index :messages, ['user_id'], :name => "user"
  end


  def self.down
    drop_table :messages
  end


end
