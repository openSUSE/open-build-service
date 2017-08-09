class AddLdapColumnToUsersTable < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :ldap, :boolean, after: :adminnote

    # ldap users have a note in the `adminnote` column that states that the user is a ldap user.
    # Let's transfer this information in a dedicated field since the adminnote field can also
    # be used for something else
    User.where(adminnote: 'User created via LDAP').update_all(ldap: true)
  end
end
