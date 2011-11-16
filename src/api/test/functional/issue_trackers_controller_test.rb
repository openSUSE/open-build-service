require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class IssueTrackersControllerTest < ActionController::IntegrationTest
  def test_should_get_index
    # Get all issue trackers
    get '/issue_trackers'
    assert_response :success
    assert_not_nil assigns(:issue_trackers)
  end

  def test_everything_at_once_because_stuff_gets_lost_between_tests_and_their_order_is_messed_up
    # Create a new issue tracker
    issue_tracker_xml = <<-EOF
    <issue-tracker>
      <name>test</name>
      <description>My test issue tracker</description>
      <regex>test#\d+test</regex>
      <kind>bugzilla</kind>
      <url>http://example.com</url>
      <show-url>http://example.com/@@@</show-url>
    </issue-tracker>
    EOF
    prepare_request_with_user "king", "sunflower"
    post '/issue_trackers', issue_tracker_xml
    assert_response :success

    # Show the newly created issue tracker
    get '/issue_trackers/test'
    assert_response :success
    get '/issue_trackers/test.json'
    assert_response :success

    # Update that issue tracker
    issue_tracker_xml = <<-EOF
    <issue-tracker>
      <name>test</name>
      <description>My even better test issue tracker</description>
      <regex>test#\d+</regex>
      <kind>bugzilla</kind>
      <url>http://test.com</url>
      <show-url>http://test.com/@@@</show-url>
    </issue-tracker>
    EOF
    prepare_request_with_user "king", "sunflower"
    put '/issue_trackers/test', issue_tracker_xml

    # Delete that issue tracker again
    prepare_request_with_user "king", "sunflower"
    delete '/issue_trackers/test'
    assert_response :success
  end
end
