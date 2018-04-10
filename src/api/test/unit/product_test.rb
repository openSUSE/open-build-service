# frozen_string_literal: true
require File.expand_path(File.dirname(__FILE__) + '/..') + '/test_helper'
require 'json'

class ProjectTest < ActiveSupport::TestCase
  fixtures :all

  def test_indexed_fixture
    # check that fixtures got indexed
    Backend::Test.start

    assert_equal 1, Product.all.count
    p = Product.find_by_name('fixed')
    assert_equal 'fixed', p.name
    assert_equal 'BaseDistro', p.package.project.name
    assert_equal 'cpe:/o:obs_fuzzies:fixed:1.2', p.cpe

    m = ProductMedium.where(product: p).first
    assert_equal 'DVD', m.name
  end
end
