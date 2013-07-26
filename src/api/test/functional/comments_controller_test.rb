require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class CommentsControllerTest < ActionDispatch::IntegrationTest 

  fixtures :all

  def setup
   prepare_request_with_user("Admin","opensuse")
  end

  def test_show_and_put_comments_on_project
    # Testing new comment creation
    put "/comments/project/openSUSE", "<comments project='openSUSE' object_type='project'><list user='Admin' title='Comment title'>Body</list></comments>"
    assert_response :success

    # Testing new comment without a body
    put "/comments/project/openSUSE", "<comments project='openSUSE' object_type='project'><list user='Admin' title='Comment title'></list></comments>"
    assert_response 403

    # Testing new comment without a title
    put "/comments/project/openSUSE", "<comments project='openSUSE' object_type='project'><list user='Admin' title=''>Body</list></comments>"
    assert_response 403 

    # Testing get request and list of comments (parent and child)
    get "/comments/project/#{projects(:openSUSE_project).name}??limit=10&offset=0"
    assert_response :success 

    assert_xml_tag :tag => 'comments', :attributes => { :object_type => 'project', :project => "#{projects(:openSUSE_project).name}" }
    assert_xml_tag :tag => 'list', :attributes => {:id => 100, :title => "Hurray"}, :content => "I am making a comment"
    assert_xml_tag :tag => 'list', :attributes => {:id => 101, :parent_id => 100, :title => ""}, :content => "I am making a reply"
  end

  def test_unidentified_project
    get "/comments/project/WhereDidThisComeFrom"
    assert_response 403

    # counter test
    get "/comments/project/openSUSE"
    assert_response :success
  end

end

