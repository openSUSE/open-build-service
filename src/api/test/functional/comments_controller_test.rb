require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class CommentsControllerTest < ActionDispatch::IntegrationTest 

  fixtures :all

  def setup
   prepare_request_with_user("Admin","opensuse")
  end

  def test_show_and_post_comments_on_project
    # Testing new comment creation
    post "/webui/comments/project/BaseDistro/new", {:project => "BaseDistro", :title => "This is a title", :body => "This is a body", :user => "Admin"}
    assert_response :success

    # testing empty comments
    post "/webui/comments/project/BaseDistro/new", {:project => "BaseDistro", :title => "This is a title", :body => "", :user => "Admin"}
    assert_response 403

    # counter test
    get "/webui/comments/project/BaseDistro"
    assert_response :success

    post "/webui/comments/project/BaseDistro/new", {:project => "BaseDistro", :title => "This is a title"}
    assert_response 400
  end

  def test_update_permissions_for_comments_on_project
    reset_auth
    prepare_request_with_user "tom", "thunder"

    put "/webui/comments/project/BaseDistro/delete", {:comment_id => 100, :user => 'tom', :body => "Comment deleted"}
    assert_response 200

    # Test to see if another user can delete a comment he/she is not associated with
    prepare_request_with_user "tom", "thunder"

    put "/webui/comments/project/BaseDistro/delete", {:comment_id => 100, :user => 'Iggy',:project => "BaseDistro", :body => "Comment deleted"}
    assert_response 400

    # Test to see check permission on editing comments

    put "/webui/comments/project/BaseDistro/edit", {:comment_id => 100, :user => 'Iggy',:project => "BaseDistro", :body => "Hurray this is a comment"}
    assert_response 400

    put "/webui/comments/project/BaseDistro/edit", {:comment_id => 100, :user => 'tom',:project => "BaseDistro", :body => "Hurray this is a comment 2"}
    assert_response 200
  end

  def test_update_permissions_for_comments_on_package
    reset_auth
    prepare_request_with_user "tom", "thunder"

    put "/webui/comments/package/BaseDistro/pack1/delete", {:comment_id => 102, :user => 'tom', :body => "Comment deleted"}
    assert_response 200

    # Test to see if another user can delete a comment he/she is not associated with
    prepare_request_with_user "tom", "thunder"

    put "/webui/comments/package/BaseDistro/pack1/delete", {:comment_id => 102, :user => 'Iggy', :body => "Comment deleted"}
    assert_response 400

    # Test to see check permission on editing comments

    put "/webui/comments/package/BaseDistro/pack1/edit", {:comment_id => 102, :user => 'Iggy', :body => "Some comment"}
    assert_response 400

    put "/webui/comments/package/BaseDistro/pack1/edit", {:comment_id => 102, :user => 'tom', :body => "Some comment from the dark knight"}
    assert_response 200
  end

  def test_update_permissions_for_comments_on_request
    reset_auth
    prepare_request_with_user "tom", "thunder"

    put "/webui/comments/request/1000/delete", {:comment_id => 103, :user => 'tom', :body => "Comment deleted"}
    assert_response 200

    # Test to see if another user can delete a comment he/she is not associated with
    prepare_request_with_user "tom", "thunder"

    put "/webui/comments/request/1000/delete", {:comment_id => 103, :user => 'Iggy', :body => "Comment deleted"}
    assert_response 400

    # Test to see check permission on editing comments

    put "/webui/comments/request/1000/edit", {:comment_id => 103, :user => 'Iggy', :body => "Comment from the president"}
    assert_response 400

    put "/webui/comments/request/1000/edit", {:comment_id => 103, :user => 'tom', :body => "Comment from anony"}
    assert_response 200
  end

end

