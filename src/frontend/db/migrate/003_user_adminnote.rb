class UserAdminnote < ActiveRecord::Migration
  def self.up
    add_column "users", "adminnote", :text
  end

  def self.down
    remove_column "users", "adminnote"
  end
end
