require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class RequestControllerTest < ActionController::IntegrationTest

  def setup
    login_Iggy
  end

  def test_request
    assert_raises(ActionController::RoutingError) do
      get "/requests"
    end
  end

  def test_my_involved_requests
    visit "/home/requests?user=Iggy"

    assert_have_selector "table#request_table tr"

    # walk over the table
    assert_have_selector('tr#tr_request_1000_1') do
      assert_have_selector('.request_source') do
        assert_have_xpath '//a[@title="home:Iggy:branches:kde4"]' do
	  assert_contain "~:kde4"
	end
      end
    end
  end

  def teardown
    logout
  end
end
