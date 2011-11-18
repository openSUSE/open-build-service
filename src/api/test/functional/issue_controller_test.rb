require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class IssueControllerTest < ActionController::IntegrationTest
  def test_should_get_show
    get '/issue_trackers/bnc/issues/123456'
    assert_response :success
  end
end
