class GroupsUser < ApplicationRecord
  belongs_to :user
  belongs_to :group

  validates :user, presence: true
  validates :group, presence: true
  validate :validate_duplicates

  protected

  validate :validate_duplicates, on: :create
  def validate_duplicates
    return unless GroupsUser.find_by(user: user, group: group)
    errors.add(:user, 'User already has this group')
  end
end

# == Schema Information
#
# Table name: groups_users
#
#  group_id   :integer          default(0), not null, indexed => [user_id]
#  user_id    :integer          default(0), not null, indexed => [group_id], indexed
#  created_at :datetime
#  email      :boolean          default(TRUE)
#  id         :integer          not null, primary key
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
