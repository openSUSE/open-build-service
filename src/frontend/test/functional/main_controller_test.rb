require File.dirname(__FILE__) + '/../test_helper'
require 'main_controller'

class MainControllerTest < Test::Unit::TestCase
  def setup
    @controller = MainController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
