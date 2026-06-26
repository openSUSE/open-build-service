require File.expand_path(File.dirname(__FILE__) + '/..') + '/test_helper'

class AboutControllerTest < ActionDispatch::IntegrationTest
  def test_about
    prepare_request_valid_user
    get '/about'
    assert_response :success
    assert_xml_tag(tag: 'about', descendant: { tag: 'revision' })
  end

  def test_about_anonymous
    reset_auth
    get '/about'
    assert_response :success
    assert_xml_tag(tag: 'about', descendant: { tag: 'revision' })
  end

  def test_application_controller
    prepare_request_valid_user
    get '/about?user[asd]=yxc'
    assert_response :bad_request
    assert_xml_tag(tag: 'status', attributes: { code: 'invalid_parameter' })
  end
end
