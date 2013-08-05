require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class CommentsControllerTest < ActionDispatch::IntegrationTest 

  fixtures :all

  def setup
   prepare_request_with_user("Admin","opensuse")
  end

  def test_show_and_post_comments_on_project
    # Testing new comment creation
    post "/webui/comments/project/openSUSE/new", "<comments project='openSUSE' object_type='project'><list user='Admin' title='Comment title'>Body</list></comments>"
    assert_response :success
  end

end

