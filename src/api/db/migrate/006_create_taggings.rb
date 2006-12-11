class CreateTaggings < ActiveRecord::Migration
  def self.up
    #creates a join model
    create_table :taggings do |t|
      t.column :taggable_id, :integer
      t.column :taggable_type, :string
      t.column :tag_id, :integer
      t.column :user_id, :integer    
    end
    add_index("taggings",["taggable_id", "taggable_type", "tag_id", "user_id"], :unique)
  end

  def self.down
    drop_table :taggings
  end
end
