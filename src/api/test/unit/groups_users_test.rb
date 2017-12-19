require File.expand_path(File.dirname(__FILE__) + '/..') + '/test_helper'

class GroupUsersTest < ActiveSupport::TestCase
  fixtures :groups, :users, :groups_users

  def test_validation
    # empty == invalid
    gu = GroupsUser.new
    assert_equal true, gu.invalid?
    assert_equal false, gu.save
    # only user
    gu.user = User.find_by_login('adrian')
    assert_equal true, gu.invalid?
    assert_equal false, gu.save
    # bad group
    gu.group = Group.find_by_title('reviewer')
    assert_equal true, gu.invalid?
    assert_equal false, gu.save
    # now good?
    gu.group = Group.find_by_title('test_group')
    # damn, already in that group
    assert_equal true, gu.invalid?
    assert_equal false, gu.save
    # but in this group there is nobody
    gu.group = Group.find_by_title('test_group_b')
    assert_equal false, gu.invalid?
    assert_equal true, gu.save
  end
end
