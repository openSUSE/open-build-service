ENV["RAILS_ENV"] = "test"
require File.expand_path(File.dirname(__FILE__) + '/../../../../config/environment')
require 'test_help'

class ActionViewExtensionsTest < Test::Unit::TestCase
  def test_stylesheet_path
    assert true
  end
end