class AddRolesUsersId < ActiveRecord::Migration[4.2]
  def self.up
    sql = 'alter table roles_users add id int(11) NOT NULL PRIMARY KEY AUTO_INCREMENT'
    ActiveRecord::Base.connection.execute(sql)
  end

  def self.down
    remove_column :roles_users, :id
  end
end
