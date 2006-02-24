require File.dirname(__FILE__) + '/../test_helper'
require 'rpm_controller'

class RpmControllerTest < Test::Unit::TestCase
  def setup
    @controller = RpmController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
