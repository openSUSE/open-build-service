require_relative '../test_helper'

class CommentsControllerTest < ActionDispatch::IntegrationTest

  test 'package comments' do
    get comments_package_path(project: 'BaseDistro3', package: 'pack2')
    assert_response 401

    login_tom
    get comments_package_path(project: 'BaseDistro3', package: 'pack2')
    assert_response :success

    assert_xml_tag tag: 'comment', attributes: { who: 'tom' }

  end

  test 'hidden project comments' do
    login_tom
    get comments_project_path(project: 'HiddenProject')
    assert_response 404 # huh? Nothing here

    prepare_request_with_user "hidden_homer", "homer"
    get comments_project_path(project: 'HiddenProject')
    assert_response :success
  end

  test 'show request comments' do
    login_tom
    get comments_request_path(id: 4)
    assert_response :success
    assert_xml_tag tag: 'comment', attributes: { who: 'tom', parent: '300' }
  end

  test 'delete comment' do
    delete comment_delete_path(300)
    assert_response 401 # no anonymous deletes

    login_tom
    get comments_request_path(id: 4)
    assert_response :success
    assert_xml_tag tag: 'comment', attributes: { who: 'tom', parent: '300' }

    delete comment_delete_path(300)
    assert_response 403 # it's Admin's comment

    delete comment_delete_path(301)
    assert_response :success

    get comments_request_path(id: 4)
    assert_response :success
    assert_no_xml_tag tag: 'comment', attributes: { who: 'tom', parent: '300' }
    assert_xml_tag tag: 'comment', attributes: { who: '_nobody_', id: '301'}, content: 'This comment has been deleted'

  end
end
