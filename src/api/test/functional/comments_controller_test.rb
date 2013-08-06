require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class CommentsControllerTest < ActionDispatch::IntegrationTest 

  fixtures :all

  def setup
   prepare_request_with_user("Admin","opensuse")
  end

  def test_show_and_post_comments_on_project
    # Testing new comment creation
    post "/webui/comments/project/BaseDistro/new", {:project => "BaseDistro", :title => "This is a title", :body => "This is a body"}
    assert_response :success

    # testing empty comments
    post "/webui/comments/project/BaseDistro/new", {:project => "BaseDistro", :title => "This is a title"}
    assert_response 403

    # counter test
    get "/webui/comments/project/BaseDistro"
    assert_response :success
  end
end

