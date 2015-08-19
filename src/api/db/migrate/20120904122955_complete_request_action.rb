class CompleteRequestAction < ActiveRecord::Migration
  def self.up
    add_column :bs_request_actions, :target_repository, :string
  end

  def self.down
    remove_column :bs_request_actions, :target_repository, :string
  end
end
