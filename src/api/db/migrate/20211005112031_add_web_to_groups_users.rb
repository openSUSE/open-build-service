class AddWebToGroupsUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :groups_users, :web, :boolean, default: true
  end
end
