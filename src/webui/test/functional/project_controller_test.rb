require File.dirname(__FILE__) + '/../test_helper'
require 'project_controller'

# Re-raise errors caught by the controller.
class ProjectController; def rescue_action(e) raise e end; end

class ProjectControllerTest < Test::Unit::TestCase
  def setup
    @controller = ProjectController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_index
    get :index
    assert_response :success
  end
  
  def test_list_all
    get :list_all
    assert_response :success
  end

  def test_list_my_unauthorized
    get :list_my
    assert_response 302
  end

  def test_list_my_authorized
    get :list_my
    assert_response :success
  end
  
  def test_edit
    get :edit, :name => "swamp"
    
    assert_response 302
    assert flash.empty?
  end

  def test_show
    get :show, :name => "swamp"

    assert_response :success
  end


  def fake_login
  end

end
