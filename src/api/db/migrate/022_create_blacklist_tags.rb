class CreateBlacklistTags < ActiveRecord::Migration
  def self.up
    create_table :blacklist_tags do |t|
      t.column :name, :string
      t.column :created_at, :datetime
    end
  end

  def self.down
    drop_table :blacklist_tags
  end
end
