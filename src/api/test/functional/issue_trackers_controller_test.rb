require File.expand_path(File.dirname(__FILE__) + '/..') + '/test_helper'

class IssueTrackersControllerTest < ActionDispatch::IntegrationTest
  def setup
    reset_auth
  end

  def test_should_get_index
    # Get all issue trackers
    login_king
    get '/issue_trackers'
    assert_response :success
    assert_select 'issue-tracker', 27
  end

  def test_create_and_update_new_trackers
    # Create a new issue tracker
    issue_tracker_xml = <<-ISSUE_TRACKER
    <issue-tracker>
      <name>test</name>
      <description>My test issue tracker</description>
      <regex>test#\d+test</regex>
      <label>test#@@@+test</label>
      <kind>bugzilla</kind>
      <enable-fetch>false</enable-fetch>
      <user>obsbugbot</user>
      <password>secret</password>
      <url>http://example.com</url>
      <show-url>http://example.com/@@@</show-url>
    </issue-tracker>
    ISSUE_TRACKER
    post '/issue_trackers', params: issue_tracker_xml
    assert_response :unauthorized
    login_adrian
    post '/issue_trackers', params: issue_tracker_xml
    assert_response :forbidden
    login_king
    post '/issue_trackers', params: issue_tracker_xml
    assert_response :success

    # Show the newly created issue tracker
    get '/issue_trackers/test'
    assert_response :success
    assert_xml_tag tag: 'name', content: 'test'
    assert_xml_tag tag: 'description', content: 'My test issue tracker'
    assert_xml_tag tag: 'regex', content: "test#\d+test"
    assert_xml_tag tag: 'label', content: 'test#@@@+test'
    assert_xml_tag tag: 'enable-fetch', content: 'false'
    assert_xml_tag tag: 'kind', content: 'bugzilla'
    assert_xml_tag tag: 'url', content: 'http://example.com'
    assert_xml_tag tag: 'show-url', content: 'http://example.com/@@@'
    assert_no_xml_tag tag: 'password'

    # FIXME: check backend data

    # Update that issue tracker
    issue_tracker_xml = <<-ISSUE_TRACKER
    <issue-tracker>
      <name>test</name>
      <description>My even better test issue tracker</description>
      <regex>tester#\d+</regex>
      <label>tester#@@@+</label>
      <enable-fetch>true</enable-fetch>
      <kind>cve</kind>
      <url>http://test.com</url>
      <show-url>http://test.com/@@@</show-url>
    </issue-tracker>
    ISSUE_TRACKER
    login_adrian
    raw_put '/issue_trackers/test', issue_tracker_xml
    assert_response :forbidden
    login_king
    raw_put '/issue_trackers/test', issue_tracker_xml
    assert_response :success
    get '/issue_trackers/test'
    assert_response :success
    assert_xml_tag tag: 'name', content: 'test'
    assert_xml_tag tag: 'description', content: 'My even better test issue tracker'
    assert_xml_tag tag: 'regex', content: "tester#\d+"
    assert_xml_tag tag: 'label', content: 'tester#@@@+'
    assert_xml_tag tag: 'enable-fetch', content: 'true'
    assert_xml_tag tag: 'kind', content: 'cve'
    assert_xml_tag tag: 'url', content: 'http://test.com'
    assert_xml_tag tag: 'show-url', content: 'http://test.com/@@@'
    assert_no_xml_tag tag: 'password'

    # Delete that issue tracker again
    login_adrian
    delete '/issue_trackers/test'
    assert_response :forbidden
    login_king
    delete '/issue_trackers/test'
    assert_response :success
  end
end
