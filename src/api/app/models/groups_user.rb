class GroupsUser < ActiveRecord::Base
  belongs_to :user, :foreign_key => 'user_id'
  belongs_to :group, :foreign_key => 'group_id'

  def validate_on_create
    unless self.user
      errors.add "Can not assign groups to nonexistent user"
    end

    if GroupsUser.find(:first, :conditions => ["user_id = ? AND group_id = ?", self.group, self.user])
      errors.add "User already has this group"
    end
  end
end
