require_relative '../test_helper'

class CommentsControllerTest < ActionDispatch::IntegrationTest
  def setup
    reset_auth
  end

  def test_package_comments
    get comments_package_path(project: 'BaseDistro3', package: 'pack2')
    assert_response :unauthorized

    login_tom
    get comments_package_path(project: 'BaseDistro3', package: 'pack2')
    assert_response :success

    assert_xml_tag tag: 'comment', attributes: { who: 'tom' }
  end

  def test_hidden_project_comments
    login_tom
    get comments_project_path(project: 'HiddenProject')
    assert_response :not_found # huh? Nothing here

    prepare_request_with_user('hidden_homer', 'buildservice')
    get comments_project_path(project: 'HiddenProject')
    assert_response :success
  end

  def test_show_request_comments
    login_tom
    get comments_request_path(request_number: 4)
    assert_response :success
    assert_xml_tag tag: 'comment', attributes: { who: 'tom', parent: '300' }
  end

  def test_delete_comment
    delete comment_delete_path(300)
    assert_response :unauthorized # no anonymous deletes

    login_tom
    get comments_request_path(request_number: 4)
    assert_response :success
    assert_xml_tag tag: 'comment', attributes: { who: 'tom', parent: '300' }

    delete comment_delete_path(300)
    assert_response :forbidden # it's Admin's comment

    delete comment_delete_path(301)
    assert_response :success

    get comments_request_path(request_number: 4)
    assert_response :success
    assert_no_xml_tag tag: 'comment', attributes: { who: 'tom', parent: '300' }
    assert_xml_tag tag: 'comment', attributes: { who: '_nobody_', id: '301' }, content: 'This comment has been deleted'
  end

  def test_delete_commented_package
    # home:king/commentpack has comments
    login_king
    delete '/source/home:king/commentpack'
    assert_response :success

    post '/source/home:king/commentpack?cmd=undelete'
    assert_response :success
  end

  def test_delete_commented_project
    # home:king has comments
    login_king
    delete '/source/home:king'
    assert_response :success

    post '/source/home:king?cmd=undelete'
    assert_response :success
  end

  def test_create_request_comment
    post create_request_comment_path(request_number: 2)
    assert_response :unauthorized # no anonymous comments

    login_adrian
    post create_request_comment_path(request_number: 2000)
    assert_response :not_found

    post create_request_comment_path(request_number: 2)
    assert_response :bad_request
    # body can't be empty
    assert_xml_tag tag: 'status', attributes: { code: 'invalid_record' }

    SendEventEmailsJob.new.perform
    assert_difference('ActionMailer::Base.deliveries.size', +1) do
      post create_request_comment_path(request_number: 2), params: 'Hallo'
      assert_response :success
      SendEventEmailsJob.new.perform
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal 'Request 2 commented by adrian (submit NeitherExisting/unknown, delete NeitherExisting/unknown2)', email.subject
    assert_equal ['tschmidt@example.com'], email.to

    get comments_request_path(request_number: 2)
    assert_xml_tag tag: 'comment', attributes: { who: 'adrian' }, content: 'Hallo'

    # just check if adrian gets the mail too - they're a commenter now
    login_dmayr
    SendEventEmailsJob.new.perform
    assert_difference('ActionMailer::Base.deliveries.size', +1) do
      post create_request_comment_path(request_number: 2), params: 'Hallo'
      assert_response :success
      SendEventEmailsJob.new.perform
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal ['adrian@example.com', 'tschmidt@example.com'], email.to.sort

    # now to something fancy
    assert_difference('ActionMailer::Base.deliveries.size', +1) do
      post create_request_comment_path(request_number: 2), params: 'Hallo @fred'
      assert_response :success
      SendEventEmailsJob.new.perform
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal ['adrian@example.com', 'fred@feuerstein.de', 'tschmidt@example.com'], email.to.sort

    # and check if @fred becomes a 'commenter' for ever
    assert_difference('ActionMailer::Base.deliveries.size', +1) do
      post create_request_comment_path(request_number: 2), params: 'Is Fred listening now?'
      assert_response :success
      SendEventEmailsJob.new.perform
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal ['adrian@example.com', 'fred@feuerstein.de', 'tschmidt@example.com'], email.to.sort
  end

  def test_create_project_comment
    post create_project_comment_path(project: 'Apache')
    assert_response :unauthorized # no anonymous comments

    login_adrian
    post create_project_comment_path(project: 'Apache')
    assert_response :bad_request
    # body can't be empty
    assert_xml_tag tag: 'status', attributes: { code: 'invalid_record' }

    SendEventEmailsJob.new.perform
    assert_difference('ActionMailer::Base.deliveries.size', +1) do
      post create_project_comment_path(project: 'Apache'), params: 'Beautiful project'
      assert_response :success
      SendEventEmailsJob.new.perform
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal 'New comment in project Apache by adrian', email.subject
    # Fred have two users and both are maintainers of the project
    assert_equal ['fred@feuerstein.de', 'fred@feuerstein.de'], email.to.sort

    get comments_project_path(project: 'Apache')
    assert_xml_tag tag: 'comment', attributes: { who: 'adrian' }, content: 'Beautiful project'
  end

  def test_create_package_comment
    post create_package_comment_path(project: 'kde4', package: 'kdebase')
    assert_response :unauthorized # no anonymous comments

    login_tom
    post create_package_comment_path(project: 'kde4', package: 'kdebase')
    assert_response :bad_request
    # body can't be empty
    assert_xml_tag tag: 'status', attributes: { code: 'invalid_record' }

    SendEventEmailsJob.new.perform
    assert_difference('ActionMailer::Base.deliveries.size', +1) do
      post create_package_comment_path(project: 'kde4', package: 'kdebase'), params: 'Hola, estoy aprendiendo español'
      assert_response :success
      SendEventEmailsJob.new.perform
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal 'New comment in package kde4/kdebase by tom', email.subject
    assert_equal ['fred@feuerstein.de', 'king@all-the-kings.org', 'fred@feuerstein.de', 'test_group@testsuite.org'].sort, email.to.sort

    get comments_package_path(project: 'kde4', package: 'kdebase')
    assert_xml_tag tag: 'comment', attributes: { who: 'tom' }, content: 'Hola, estoy aprendiendo español'
  end

  def test_create_a_comment_that_only_mentioned_people_will_notice
    login_tom
    SendEventEmailsJob.new.perform
    assert_difference('ActionMailer::Base.deliveries.size', +1) do
      # Trolling
      post create_package_comment_path(project: 'BaseDistro', package: 'pack1'), params: "I preffer Apache1, don't you? @fred"
      assert_response :success
      SendEventEmailsJob.new.perform
    end

    email = ActionMailer::Base.deliveries.last
    assert_equal 'New comment in package BaseDistro/pack1 by tom', email.subject
    # There are not maintainers for BaseDistro or pack1, so only @fred is notified
    assert_equal ['fred@feuerstein.de'], email.to

    get comments_package_path(project: 'BaseDistro', package: 'pack1')
    assert_xml_tag tag: 'comment', attributes: { who: 'tom' }, content: "I preffer Apache1, don't you? @fred"
  end
end
