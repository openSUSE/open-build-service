# frozen_string_literal: true
class DisallowNullForGroupIdInGroupsUsers < ActiveRecord::Migration[5.1]
  def up
    # Remove all dangling groups users that got created since 18680d611347d312
    GroupsUser.where(group_id: nil).destroy_all
    change_column :groups_users, :group_id, :integer, null: false, default: 0, before: :user_id
  end

  def down
    change_column :groups_users, :group_id, :integer, null: true, default: 0, before: :user_id
  end
end
