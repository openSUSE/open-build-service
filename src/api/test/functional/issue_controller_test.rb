require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class IssueControllerTest < ActionController::IntegrationTest
  def test_get_issues
    # get full issue
    get '/issue_trackers/bnc/issues/123456'
    assert_response :success
    assert_tag :tag => 'name', :content => "123456"
    assert_tag :tag => 'issue_tracker', :content => "bnc"
    assert_tag :tag => 'long_name', :content => "bnc#123456"
    assert_tag :tag => 'url', :content => "https://bugzilla.novell.com/show_bug.cgi?id=123456"
    assert_tag :tag => 'state', :content => "RESOLVED"
    assert_tag :tag => 'description', :content => "OBS is not bugfree!"
    assert_tag :parent => { :tag => 'owner' }, :tag => 'login', :content => "fred"
    assert_tag :parent => { :tag => 'owner' }, :tag => 'email', :content => "fred@feuerstein.de"
    assert_tag :parent => { :tag => 'owner' }, :tag => 'realname', :content => "Frederic Feuerstone"
    assert_no_tag :tag => 'password'

    # get new, incomplete issue .. don't crash ...
    get '/issue_trackers/bnc/issues/1234'
    assert_response :success
    assert_tag :tag => 'name', :content => "1234"
    assert_tag :tag => 'issue_tracker', :content => "bnc"
    assert_no_tag :tag => 'password'
  end
end
