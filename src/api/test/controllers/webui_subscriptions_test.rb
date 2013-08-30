require 'test_helper'

class WebuiSubscriptionsTest < ActionDispatch::IntegrationTest
  fixtures :all

  test "get subscriptions for kde" do
    login_Iggy
    get webui_project_subscriptions_path(project_id: 'kde4')
    assert_response :success
  end
end

