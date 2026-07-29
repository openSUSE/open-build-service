class GroupsUser < ApplicationRecord
  belongs_to :user
  belongs_to :group

  validates :user_id, comparison: { other_than: User.find_nobody!.id , message: "_nobody_ can not join groups" }
  validates :user_id, uniqueness: { scope: :group_id, message: 'belongs to this group already' }

  after_create :create_event

  private

  def create_event
    Event::AddedUserToGroup.create(group: group.title, member: user.login, who: User.session&.login)
  end
end

# == Schema Information
#
# Table name: groups_users
#
#  id         :integer          not null, primary key
#  email      :boolean          default(TRUE)
#  web        :boolean          default(TRUE)
#  created_at :datetime
#  group_id   :integer          default(0), not null, uniquely indexed => [user_id]
#  user_id    :integer          default(0), not null, uniquely indexed => [group_id], indexed
#
# Indexes
#
#  groups_users_all_index  (group_id,user_id) UNIQUE
#  user_id                 (user_id)
#
# Foreign Keys
#
#  groups_users_ibfk_1  (group_id => groups.id)
#  groups_users_ibfk_2  (user_id => users.id)
#
