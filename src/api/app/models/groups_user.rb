class GroupsUser < ActiveRecord::Base
  belongs_to :user, :foreign_key => 'user_id'
  belongs_to :group, :foreign_key => 'group_id'

  validates :user, :presence => true
  validates :group, :presence => true
  validate :validate_duplicates

  attr_accessible :group, :user

  protected
  validate :validate_duplicates, :on => :create
  def validate_duplicates
    if GroupsUser.where("user_id = ? AND group_id = ?", self.user, self.group).first
      errors.add(:user, "User already has this group")
    end
  end
end
