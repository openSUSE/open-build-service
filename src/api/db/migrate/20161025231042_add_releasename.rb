class AddReleasename < ActiveRecord::Migration
  def self.up
    add_column :packages, :releasename, :string
  end

  def self.down
    remove_column :packages, :releasename
  end
end
