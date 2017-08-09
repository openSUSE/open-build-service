class RenameLdapColumnInUsersTable < ActiveRecord::Migration[5.1]
  def change
    rename_column :users, :ldap, :external
  end
end
