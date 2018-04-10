# frozen_string_literal: true

require File.expand_path(File.dirname(__FILE__) + '/..') + '/test_helper'

class PublicHelperTest < ActiveSupport::TestCase
  YMP_URL = 'http://example.com/ymp'
  include PublicHelper

  def test_ymp_url
    assert_equal "#{YMP_URL}/foo", ymp_url('foo')
    assert_equal "#{YMP_URL}/", ymp_url('')
  end
end
