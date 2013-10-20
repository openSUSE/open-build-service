class MakeCommentUsersIds < ActiveRecord::Migration
  def up
    ActiveRecord::Base.record_timestamps = false
    add_column :comments, :user_id, :integer, null: false
    Comment.all.each do |c|
      c.user_id = User.find_by_login(c.user).id
      c.save
    end
    remove_column :comments, :user
  end
end
