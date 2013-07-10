require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class CommentsControllerTest < ActionDispatch::IntegrationTest 

  fixtures :all

  def setup
   prepare_request_with_user("Admin","opensuse")
  end

  def test_get_project
    get "/comments/#{projects(:openSUSE_project).name}??limit=10&offset=0"
    assert_response :success 
  end

  def test_get_package
    get "/comments/#{projects(:openSUSE_project).name}/#{packages(:openSUSE_package).name}??limit=10&offset=0"
    assert_response :success 
  end

  def test_get_request
    get "/comments/request/#{bs_requests(:openSUSE).id}??limit=10&offset=0"
    assert_response :success 
  end
end

