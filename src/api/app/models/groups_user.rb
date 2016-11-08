class GroupsUser < ApplicationRecord
  belongs_to :user
  belongs_to :group

  validates :user, presence: true
  validates :group, presence: true
  validate :validate_duplicates

  protected

  validate :validate_duplicates, on: :create
  def validate_duplicates
    if GroupsUser.find_by(user: user, group: group)
      errors.add(:user, "User already has this group")
    end
  end
end
