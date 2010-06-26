require File.dirname(__FILE__) + '/../test_helper'        

class ProjectControllerTest < ActionController::IntegrationTest

  def setup 
    login_tom
  end

  def test_edit
    get '/user/edit'
    assert_response :success
  end

end
