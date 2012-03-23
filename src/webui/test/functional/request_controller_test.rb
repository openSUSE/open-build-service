require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class RequestControllerTest < ActionController::IntegrationTest

  def setup
    login_Iggy
  end

  def test_request
    get "/requests"
    assert_response 404
  end

  def test_my_involved_requests
    get "/home/requests?user=Iggy"
    assert_response :success

    assert_tag :tag => "table", :attributes => { :id => "request_table" }, :descendant => { :tag => "tr" }

    # walk over the table
    assert_select('tr#tr_request_1000') do
      assert_select('.request_source') do
        assert_tag :tag => "a", :attributes => { :title => "home:Iggy:branches:kde4" }, :content => "~:kde4"
      end
    end
  end

  def teardown
    logout
  end
end
