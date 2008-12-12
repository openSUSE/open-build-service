require File.dirname(__FILE__) + '/../test_helper'
require 'result_controller'

class ResultControllerTest < Test::Unit::TestCase
  def setup
    @controller = ResultController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
