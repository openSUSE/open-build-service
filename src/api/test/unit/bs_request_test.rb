require File.dirname(__FILE__) + '/../test_helper'
require 'models/bs_request'

class BsRequestTest < ActiveSupport::TestCase

  fixtures :db_projects, :db_packages, :users, :project_user_role_relationships, :roles, :static_permissions, :roles_static_permissions

  def setup
    @tom = User.find_by_login("tom")
    @tscholz = User.find_by_login("tscholz")
  end

  def test_create_no_project
    req = BsRequest.find(:name => "no_such_project")
    assert_equal "Unknown source project home:guest", req.check_create(@tom)

    req = BsRequest.find(:name => "no_such_project2")
    assert_equal "Unknown target project openSUSE:Factory", req.check_create(@tscholz)
  end

  def test_create_no_package
    req = BsRequest.find(:name => "no_such_package")
    assert_equal "Unknown source package mypackage in project home:tscholz", req.check_create(@tom)
  end

  def test_create_works
    req = BsRequest.find(:name => "works")
    assert_equal "No permission to create request for package 'TestPack' in project 'home:tscholz'", req.check_create(@tom)
    assert_equal nil, req.check_create(@tscholz)
  end

  def test_oldformat
    req = BsRequest.find(:name => "oldformat")
    req2 = BsRequest.find(:name => "newformat")
    assert_equal req2.dump_xml, req.dump_xml
  end

end

