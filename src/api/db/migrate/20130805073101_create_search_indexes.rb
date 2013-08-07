class CreateSearchIndexes < ActiveRecord::Migration
  def change
    add_index :linked_packages, :links_to_id
  end
end
