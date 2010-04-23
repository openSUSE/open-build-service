class UpdateUserTable < ActiveRecord::Migration
  def self.up
    # remove unneeded data
    remove_column :users, :source_host
    remove_column :users, :source_port
    remove_column :users, :rpm_host
    remove_column :users, :rpm_port
  end

  def self.down
    add_column :users, :source_host, :string, :limit => 40
    add_column :users, :source_port, :integer
    add_column :users, :rpm_host, :string, :limit => 40
    add_column :users, :rpm_port, :integer
  end
end
