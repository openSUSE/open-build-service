class AddIndexForTaggableType < ActiveRecord::Migration
  def self.up
    add_index("taggings","taggable_type")
  end

  def self.down
    remove_index("taggings","taggable_type")
  end
end
