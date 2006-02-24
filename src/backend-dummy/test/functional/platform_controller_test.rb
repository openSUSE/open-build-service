require File.dirname(__FILE__) + '/../test_helper'
require 'platform_controller'

# Re-raise errors caught by the controller.
class PlatformController; def rescue_action(e) raise e end; end

class PlatformControllerTest < Test::Unit::TestCase
  def setup
    @controller = PlatformController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
