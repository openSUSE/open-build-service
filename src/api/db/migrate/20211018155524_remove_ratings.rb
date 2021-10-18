class RemoveRatings < ActiveRecord::Migration[6.1]
  def change
    drop_table :ratings, id: :integer, options: 'ENGINE=InnoDB ROW_FORMAT=DYNAMIC' do |t|
      t.integer 'score'
      t.integer 'db_object_id'
      t.string 'db_object_type', collation: 'utf8_general_ci'
      t.datetime 'created_at'
      t.integer 'user_id'
      t.index ['db_object_id'], name: 'object'
      t.index ['user_id'], name: 'user'
    end
  end
end
