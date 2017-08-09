class AddDefaultValueForLdapColumnInUsersTable < ActiveRecord::Migration[5.1]
  def change
    change_column :users, :ldap, :boolean, default: false, after: :adminnote

    User.where(ldap: nil).update_all(ldap: false)
  end
end
