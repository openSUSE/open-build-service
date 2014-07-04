require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"
require 'json'

class ProjectTest < ActiveSupport::TestCase
  fixtures :all

  def test_indexed_fixture
    #check that fixtures got indexed
    Suse::Backend.start_test_backend
    assert_equal 1, Product.all.count
    p = Product.all.first
    assert_equal "fixed", p.name
    assert_equal "BaseDistro", p.package.project.name
    assert_equal "cpe:/o:obs_fuzzies:fixed:1.2", p.cpe
  end

end
  
