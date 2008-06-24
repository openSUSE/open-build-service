class AddRatingTable < ActiveRecord::Migration


  def self.up
    create_table :ratings do |t|
      t.column :score, :integer
      t.column :object_id, :integer
      t.column :object_type, :string
      t.column :created_at, :timestamp
      t.column :user_id, :integer
    end
    add_index :ratings, ['object_id'], :name => "object"
    add_index :ratings, ['user_id'], :name => "user"
  end


  def self.down
    drop_table :ratings
  end


end
