require File.dirname(__FILE__) + '/../test_helper'
require 'apidocs_controller'

class ApidocsControllerTest < Test::Unit::TestCase
  def setup
    @controller = ApidocsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
