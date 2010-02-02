class CaseSensitiveLoginName < ActiveRecord::Migration
  def self.up
    remove_index "users", :name => "users_login_index"
    change_column :users, :login, :binary, :limit => 255
    execute "CREATE UNIQUE INDEX users_login_index ON users (login(255));"
  end

  def self.down
    change_column :users, :login, :string
  end
end
