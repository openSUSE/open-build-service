class AddRenderedMetaCache < ActiveRecord::Migration
  def self.up
    create_table :meta_cache do |t|
      t.integer :cachable_id, :null => false
      t.string :cachable_type, :null => false
      t.text :content, :null => false
    end

    add_index :meta_cache, [:cachable_id, :cachable_type], :unique => true
  end

  def self.down
    drop_table :meta_cache
  end
end
