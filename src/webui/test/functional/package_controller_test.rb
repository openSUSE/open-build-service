require File.dirname(__FILE__) + '/../test_helper'
require 'package_controller'

# Re-raise errors caught by the controller.
class PackageController; def rescue_action(e) raise e end; end

class PackageControllerTest < Test::Unit::TestCase
  def setup
    @controller = PackageController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_new
    get :new
    
    assert_response 302
  end

end
