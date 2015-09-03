class RemoveIndexFromPathElementPosition < ActiveRecord::Migration
  def change
    remove_index :path_elements, name: :parent_repo_pos_index
  end
end
