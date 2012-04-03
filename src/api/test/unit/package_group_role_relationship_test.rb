require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class PackageGroupRoleRelationshipTest < ActiveSupport::TestCase

  def test_validation
    # empty == invalid
    pgr = PackageGroupRoleRelationship.new 
    assert_equal true, pgr.invalid?
    assert_equal false, pgr.save
    # only role
    pgr.role = Role.find_by_title("maintainer")
    assert_equal true, pgr.invalid?
    assert_equal false, pgr.save
    pgr.db_package = DbPackage.find_by_name("kdelibs")
    assert_equal true, pgr.invalid?
    assert_equal false, pgr.save
    # bad group
    pgr.group = Group.find_by_title("reviewer")
    assert_equal true, pgr.invalid?
    assert_equal false, pgr.save
    # now good?
    pgr.group = Group.find_by_title("test_group")
    assert_equal true, pgr.invalid?
    pgr.group = Group.find_by_title("test_group_b")
    assert_equal false, pgr.invalid?
    assert_equal true, pgr.save

    pgr = pgr.clone
    # not another time
    assert_equal false, pgr.valid?
  end
  
end
