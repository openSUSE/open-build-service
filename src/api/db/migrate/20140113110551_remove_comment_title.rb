class RemoveCommentTitle < ActiveRecord::Migration
  def up
    Comment.all.each do |c|
      c.body = c.title + "\n\n" + c.body unless c.parent_id
      c.save
    end
    remove_column :comments, :title
  end
end
