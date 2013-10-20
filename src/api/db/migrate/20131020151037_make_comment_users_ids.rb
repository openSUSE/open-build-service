class MakeCommentUsersIds < ActiveRecord::Migration
  class Comment < ActiveRecord::Base
  end

  def up
    ActiveRecord::Base.record_timestamps = false
    add_column :comments, :user_id, :integer, null: false
    nobody = User.find_by_login('_nobody_')
    Comment.all.each do |c|
      cu = User.find_by_login(c.read_attribute(:user))
      cu ||= nobody
      c.user_id = cu.id
      c.save
    end
    remove_column :comments, :user
  end
end
