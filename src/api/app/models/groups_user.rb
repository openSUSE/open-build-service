class GroupsUser < ApplicationRecord
  belongs_to :user
  belongs_to :group

  validates :user, :presence => true
  validates :group, :presence => true
  validate :validate_duplicates

  protected

  validate :validate_duplicates, :on => :create
  def validate_duplicates
    if GroupsUser.where("user_id = ? AND group_id = ?", self.user, self.group).first
      errors.add(:user, "User already has this group")
    end
  end
end
