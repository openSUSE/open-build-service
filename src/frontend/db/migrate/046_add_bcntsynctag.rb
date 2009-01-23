class AddBcntsynctag < ActiveRecord::Migration
  def self.up
    add_column :db_packages, :bcntsynctag, :string
  end

  def self.down
    remove_column :db_packages, :bcntsynctag
  end
end
