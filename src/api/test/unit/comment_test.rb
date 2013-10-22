require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class CommentTest < ActiveSupport::TestCase

  test "Comment checks" do
    user = User.find_by_login('Admin')
    com = CommentPackage.new(:user => user, :title => "Comment title", :body => "Comment body")
    assert_equal false, com.save
    assert_equal ["can't be blank"], com.errors[:package]
  end


end
