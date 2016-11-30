class AddCommentableToComments < ActiveRecord::Migration[5.0]
  def change
    add_reference :comments, :commentable, polymorphic: true, index: true
  end
end
