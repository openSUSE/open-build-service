require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class UserTest < ActiveSupport::TestCase

  fixtures :all

  def setup
    @project = db_projects( :home_Iggy )
    @user = User.find_by_login("Iggy")
  end
  
  def test_basics
    assert @project
    assert @user
  end

  def test_access
    assert @user.has_local_permission? 'change_project', @project
    assert @user.has_local_permission? 'change_package', db_packages( :TestPack )
    
    m = Role.find_by_title("maintainer")
    assert @user.has_local_role?(m, @project )
    assert @user.has_local_role?(m, db_packages( :TestPack ) )

    b = Role.find_by_title "bugowner"
    assert !@user.has_local_role?(b, @project )
    assert !@user.has_local_role?(m, db_projects( :kde4 ))

    tom = users( :tom )
    assert !tom.has_local_permission?('change_project', db_projects( :kde4 ))
    assert !tom.has_local_permission?('change_package', db_packages( :kdelibs ))
  end 

  def test_group
    assert !@user.is_in_group?("notexistant")
    assert !@user.is_in_group?("test_group")
    assert users( :adrian).is_in_group?("test_group")
    assert !users( :adrian).is_in_group?("test_group_b")
    assert !users( :adrian).is_in_group?("notexistant")
  end

end

