require File.expand_path(File.dirname(__FILE__) + '/..') + '/test_helper'

class CommentTest < ActiveSupport::TestCase
  test 'validations' do
    user = User.find_by_login('Admin')
    com = Comment.new(user: user, body: 'Comment body')
    assert_equal false, com.save
    assert_equal ["can't be blank"], com.errors[:commentable]
  end
end
