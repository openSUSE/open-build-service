require File.dirname(__FILE__) + '/../test_helper'
require 'status_message_controller'

# Re-raise errors caught by the controller.
class StatusMessageController; def rescue_action(e) raise e end; end

class StatusMessageControllerTest < Test::Unit::TestCase
  def setup
    @controller = StatusMessageController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
