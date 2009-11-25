class CreateIndexForMore < ActiveRecord::Migration
  def self.up
	add_index :flags, ['db_package_id', 'type']
        add_index :package_user_role_relationships, :bs_user_id
  end

  def self.down
	remove_index :flags, :column => ['db_package_id', 'type']
	remove_index :package_user_role_relationships, :column => ['bs_user_id']
  end
end
