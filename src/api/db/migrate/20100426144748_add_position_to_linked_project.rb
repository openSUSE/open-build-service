class AddPositionToLinkedProject < ActiveRecord::Migration
  def self.up
    add_column :linked_projects, :position, :integer
  end

  def self.down
    remove_column :linked_projects, :position
  end
end
