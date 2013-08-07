require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class CommentTest < ActiveSupport::TestCase
  fixtures :users

  test "Comment saved succesfully" do
  	user = User.find_by_login('Admin')
  	com = Comment.new(:user => user, :title => "Comment title", :body => "Comment body")
  	com.save

  	# Getting newly comment created
  	new_comment_created = Comment.find(com.id).present?
  	assert_equal true, new_comment_created
  end


end
