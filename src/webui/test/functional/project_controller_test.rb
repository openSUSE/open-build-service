require File.dirname(__FILE__) + '/../test_helper'        
require 'project_controller'                              

# Re-raise errors caught by the controller.
class ProjectController; def rescue_action(e) raise e end; end

class ProjectControllerTest < ActionController::IntegrationTest
  def test_list
    get "/project"
    assert_response 302

    get "/project/list_public"
    assert_response :success
  end
 
  def test_show
    get "/project/show?project=Mono"
    assert_response :success
  end
end
