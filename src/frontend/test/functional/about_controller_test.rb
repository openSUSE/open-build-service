require File.dirname(__FILE__) + '/../test_helper'
require 'about_controller'

class AboutControllerTest < Test::Unit::TestCase
  def setup
    @controller = AboutController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
