class DropMessages < ActiveRecord::Migration[5.2]
  def change
    drop_table :messages do |t|
      t.integer  'db_object_id'
      t.string   'db_object_type', collation: 'utf8_general_ci'
      t.integer  'user_id'
      t.datetime 'created_at'
      t.boolean  'send_mail'
      t.datetime 'sent_at'
      t.boolean  'private'
      t.integer  'severity'
      t.text     'text', limit: 65_535, collation: 'utf8mb4_unicode_ci'
      t.index ['db_object_id'], name: 'object', using: :btree
      t.index ['user_id'], name: 'user', using: :btree
    end
  end
end
