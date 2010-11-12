require File.dirname(__FILE__) + '/../test_helper'

class LinkedProjectTest < ActiveSupport::TestCase
  fixtures :linked_projects, :db_projects

  def test_validation
    prj = LinkedProject.new
    assert_equal false, prj.valid?
    prj.db_project = DbProject.find_by_name("home:Iggy")
    assert_equal false, prj.valid?
    prj.linked_db_project = DbProject.find_by_name("BaseDistro2")
    assert_equal true, prj.valid?
    assert_equal true, prj.save
    prj2 = prj.clone
    # already linked
    assert_equal false, prj2.valid?
  end
  
end
