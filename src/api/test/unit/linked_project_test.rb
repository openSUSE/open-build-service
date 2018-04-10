# frozen_string_literal: true
require File.expand_path(File.dirname(__FILE__) + '/..') + '/test_helper'

class LinkedProjectTest < ActiveSupport::TestCase
  fixtures :linked_projects, :projects

  def test_validation
    prj = LinkedProject.new
    assert_equal false, prj.valid?
    prj.project = Project.find_by_name('home:Iggy')
    assert_equal false, prj.valid?
    prj.linked_db_project = Project.find_by_name('BaseDistro2.0')
    assert_equal true, prj.valid?
    assert_equal true, prj.save
    prj2 = prj.clone
    # already linked
    assert_equal false, prj2.valid?
  end
end
