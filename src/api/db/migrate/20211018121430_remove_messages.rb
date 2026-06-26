class RemoveMessages < ActiveRecord::Migration[6.1]
  def change
    drop_table :messages, id: :integer, options: 'ENGINE=InnoDB ROW_FORMAT=DYNAMIC' do |t|
      t.integer 'db_object_id'
      t.string 'db_object_type', collation: 'utf8_general_ci'
      t.integer 'user_id'
      t.datetime 'created_at'
      t.boolean 'send_mail'
      t.datetime 'sent_at'
      t.boolean 'private'
      t.integer 'severity'
      t.text 'text'
      t.index ['db_object_id'], name: 'object'
      t.index ['user_id'], name: 'user'
    end
  end
end
