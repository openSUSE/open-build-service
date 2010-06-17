require File.dirname(__FILE__) + '/../test_helper'        
require 'project_controller'                              

# Re-raise errors caught by the controller.
class ProjectController; def rescue_action(e) raise e end; end

class ProjectControllerTest < ActionController::IntegrationTest
  def test_list
    get "/project"
    assert_redirected_to "/project/list_public"
    get "/project/list_public"
    assert_response :success
    assert assigns(:important_projects).each.blank?
    assert( assigns(:projects).size == 2 )
  end
 
  def test_show
    get "/project/show?project=Mono"
    assert_response :success
    assert( assigns(:packages).each.size == 4 )
    assert( assigns(:problem_packages) == 0 )
    assert( assigns(:project) )
  end

  def test_packages
    get "/project/packages?project=Mono:Factory"
    assert_response :success
    assert( assigns(:packages).each.size == 4 )
    assert( assigns(:project) )
  end

end
