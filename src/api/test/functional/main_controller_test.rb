require File.expand_path(File.dirname(__FILE__) + '/..') + '/test_helper'

class MainTests < ActionDispatch::IntegrationTest
  def setup
    reset_auth
  end

  def test_index
    get '/'
    assert_response 401

    login_tom
    get '/'
    assert_redirected_to '/about'
    follow_redirect!

    assert_xml_tag parent: { tag: 'about' }, tag: 'title'
  end
end
