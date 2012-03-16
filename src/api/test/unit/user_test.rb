require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class UserTest < ActiveSupport::TestCase
  fixtures :all

  def setup
    @project = DbProject.find( :first, :conditions => { :name => "home:Iggy" } )
    @user = User.find_by_login("Iggy")
  end
  
  def test_basics
    assert @project
    assert @user
  end

  def test_access
    assert @user.has_local_permission? 'change_project', @project
  end 
end

