class AddNomailToGroupsUsers < ActiveRecord::Migration
  def change
    add_column :groups_users, :email, :boolean, default: true
  end
end
