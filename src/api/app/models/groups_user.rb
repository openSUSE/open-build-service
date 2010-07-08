class GroupsUser < ActiveRecord::Base
  belongs_to :user, :foreign_key => 'user_id'
  belongs_to :group, :foreign_key => 'group_id'

  def validate_on_create
    unless self.user
      errors.add "Can not assign groups to nonexistent user"
    end
    unless self.group
      errors.add "Need a group to assign users"
    end
    return unless errors.empty?
    if GroupsUser.find(:first, :conditions => ["user_id = ? AND group_id = ?", self.user, self.group])
      errors.add "User already has this group"
    end
  end
end
