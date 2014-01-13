class RemoveCommentTitle < ActiveRecord::Migration
  def up
    Comment.all.each do |c|
      unless c.parent_id
        c.body = c.title + "\n\n" + c.body
      end
      c.save
    end
    remove_column :comments, :title
  end
end
