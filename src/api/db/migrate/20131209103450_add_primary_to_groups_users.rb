class AddPrimaryToGroupsUsers < ActiveRecord::Migration
  class GroupsUser < ActiveRecord::Base
  end

  def change
    add_column :groups_users, :id, :int, null: false

    GroupsUser.transaction do
      gus = GroupsUser.all.to_a
      GroupsUser.delete_all

      id = 1
      gus.each do |gu|
        GroupsUser.create group_id: gu.group_id, user_id: gu.user_id, id: id, created_at: gu.created_at, email: gu.email
        id += 1
      end
    end
    execute("alter table groups_users add PRIMARY KEY (`id`)")
    execute("alter table groups_users modify COLUMN id int(11) NOT NULL AUTO_INCREMENT")
  end
end
