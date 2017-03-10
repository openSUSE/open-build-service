class GroupMaintainer < ApplicationRecord
  belongs_to :user
  belongs_to :group

  validates :user, presence: true
  validates :group, presence: true
  validate :validate_duplicates

  protected

  validate :validate_duplicates, on: :create
  def validate_duplicates
    return unless GroupMaintainer.find_by(user: user, group: group)
    errors.add(:user, "Maintainer already has this group")
  end
end

# == Schema Information
#
# Table name: group_maintainers
#
#  id       :integer          not null, primary key
#  group_id :integer
#  user_id  :integer
#
# Indexes
#
#  group_id  (group_id)
#  user_id   (user_id)
#
