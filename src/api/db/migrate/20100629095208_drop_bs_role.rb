class DropBsRole < ActiveRecord::Migration
  def self.up
    drop_table "bs_roles" if ActiveRecord::Base.connection.tables.include?("bs_roles")
  end

  def self.down
  end
end
