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

    prepare_request_with_user 'hidden_homer', 'homer'
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
    assert_xml_tag tag: 'comment', attributes: { who: '_nobody_', id: '301' }, content: 'This comment has been deleted'

  end

  test 'delete commented package' do
    # home:king/commentpack has comments
    login_king
    delete '/source/home:king/commentpack'
    assert_response :success
  end

  test 'delete commented project' do
    # home:king has comments
    login_king
    delete '/source/home:king'
    assert_response :success
  end

  test 'create request comment' do
    post create_request_comment_path(id: 2)
    assert_response 401 # no anonymous comments

    login_adrian
    post create_request_comment_path(id: 2000)
    assert_response 404

    post create_request_comment_path(id: 2)
    assert_response 400
    # body can't be empty
    assert_xml_tag tag: 'status', attributes: { code: 'invalid_record' }

    assert_difference 'ActionMailer::Base.deliveries.size', +1 do
      raw_post create_request_comment_path(id: 2), 'Hallo'
      assert_response :success
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal 'Request 2 commented by adrian (submit NeitherExisting/unknown, delete NeitherExisting/unknown2)', email.subject
    assert_equal ['tschmidt@example.com'], email.to

    get comments_request_path(id: 2)
    assert_xml_tag tag: 'comment', attributes: { who: 'adrian' }, content: 'Hallo'

    # just check if adrian gets the mail too - he's a commenter now
    login_dmayr
    assert_difference 'ActionMailer::Base.deliveries.size', +1 do
      raw_post create_request_comment_path(id: 2), 'Hallo'
      assert_response :success
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal %w(adrian@example.com tschmidt@example.com), email.to

    # now to something fancy
    assert_difference 'ActionMailer::Base.deliveries.size', +1 do
      raw_post create_request_comment_path(id: 2), 'Hallo @fred'
      assert_response :success
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal %w(adrian@example.com fred@feuerstein.de tschmidt@example.com), email.to
  end
end
