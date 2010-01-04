require File.dirname(__FILE__) + '/../test_helper'
require 'request_controller'

# Re-raise errors caught by the controller.
class RequestController; def rescue_action(e) raise e end; end

class RequestControllerTest < ActionController::IntegrationTest 
  
  fixtures :db_projects, :db_packages, :users, :project_user_role_relationships, :roles, :static_permissions, :roles_static_permissions

  def setup
    @controller = RequestController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
 
    @tom = User.find_by_login("tom")
    @tscholz = User.find_by_login("tscholz")
  end

  def test_submit_request
    req = BsRequest.find(:name => "no_such_project")
    
    prepare_request_with_user @request, "tscholz", "asdfasdf"
    get "/request/10101"
    assert_response :success

    #get "/request/#{id}?newstate=#{changestate}&cmd=changestate"

    #Precondition check: Get all tags for tscholz and the home:project.  
    #
    #put "/request?cmd=create", req.dump_xml

  end

end

