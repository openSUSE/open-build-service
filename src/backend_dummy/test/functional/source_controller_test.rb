require File.dirname(__FILE__) + '/../test_helper'
require 'source_controller'

# Re-raise errors caught by the controller.
class SourceController; def rescue_action(e) raise e end; end

class SourceControllerTest < Test::Unit::TestCase
  def setup
    @controller = SourceController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_index
    get :index
    assert_response :success
  end
end
