require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class CommentsControllerTest < ActionDispatch::IntegrationTest 

  fixtures :all

  def setup
    prepare_request_with_user("king","sunflower")
  end

  def test_writing_project_comments
    # Testing new comment creation
    post "/webui/comments/project/BaseDistro2.0/new", {:title => "This is a title", :body => "This is a body"}
    assert_response :success

    # Empty title or body shouldn't work
    post "/webui/comments/project/BaseDistro2.0/new", {:title => "", :body => "This is a body"}
    assert_response 403
    post "/webui/comments/project/BaseDistro2.0/new", {:title => "This is a title", :body => ""}
    assert_response 403
  end

  def test_writing_package_comments
    # Testing new comment creation
    post "/webui/comments/package/BaseDistro2.0/pack2/new", {:title => "This is a title", :body => "This is a body"}
    assert_response :success

    # Empty title or body shouldn't work
    post "/webui/comments/package/BaseDistro2.0/pack2/new", {:title => "", :body => "This is a body"}
    assert_response 403
    post "/webui/comments/package/BaseDistro2.0/pack2/new", {:title => "This is a title", :body => ""}
    assert_response 403
  end

  def test_writing_request_comments
    # Testing new comment creation
    post "/webui/comments/request/998/new", {:title => "This is a title", :body => "This is a body"}
    assert_response :success

    # Empty title or body shouldn't work
    post "/webui/comments/request/998/new", {:title => "", :body => "This is a body"}
    assert_response 403
    post "/webui/comments/request/998/new", {:title => "This is a title", :body => ""}
    assert_response 403
  end

  def test_reading_project_comments
    # Getting comments
    get "/webui/comments/project/BaseDistro"
    assert_response :success
  end

  def test_deleting_project_comments
    # Admins should be able to delete all comments
    post "/webui/comments/project/BaseDistro/delete", {:comment_id => 102}
    assert_response 200

    reset_auth
    login_tom

    # Users should be able to delete their own comments
    post "/webui/comments/project/BaseDistro/delete", {:comment_id => 101}
    assert_response 200

    # Users shouldn't be able to delete a comment they are not associated with
    post "/webui/comments/project/BaseDistro/delete", {:comment_id => 100}
    assert_response 400

  end

  def test_deleting_package_comments
    # Admins should be able to delete all comments
    post "/webui/comments/package/BaseDistro/pack1/delete", {:comment_id => 202}
    assert_response 200

    reset_auth
    login_tom
    
    # Users should be able to delete their own comments
    post "/webui/comments/package/BaseDistro/pack1/delete", {:comment_id => 201}
    assert_response 200

    # Users shouldn't be able to delete a comment they are not associated with
    put "/webui/comments/package/BaseDistro/pack1/delete", {:comment_id => 200}
    assert_response 404
  end

  def test_delete_request_comments
    # Admins should be able to delete all comments
    post "/webui/comments/request/1000/delete", {:comment_id => 302}
    assert_response 200

    reset_auth
    login_tom

    # Users should be able to delete their own comments
    post "/webui/comments/request/1000/delete", {:comment_id => 301}
    assert_response 200

    # Users shouldn't be able to delete a comment they are not associated with
    put "/webui/comments/request/1000/delete", {:comment_id => 300}
    assert_response 404
  end

end

