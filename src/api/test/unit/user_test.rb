require File.dirname(__FILE__) + '/../test_helper'
require 'models/user'

class UserTest < ActiveSupport::TestCase
  fixtures :db_projects, :db_packages, :users, :project_user_role_relationships, :roles, :static_permissions, :roles_static_permissions

  def setup
    @project = DbProject.find( :first, :conditions => { :name => "home:tscholz" } )
    @user = User.find_by_login("tscholz")
  end
  
  def test_basics
    assert @project
    assert @user
  end

  def test_access
    assert @user.has_local_permission? 'change_project', @project
  end 
end

