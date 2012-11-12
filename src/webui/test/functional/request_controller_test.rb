require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class RequestControllerTest < ActionDispatch::IntegrationTest

  def setup
    super
    login_Iggy
  end

  def test_my_involved_requests
    visit "/home/requests?user=Iggy"

    assert page.has_selector? "table#request_table tr"

    # walk over the table
    rs = find('tr#tr_request_1000_1').find('.request_source')
    assert rs.find(:xpath, '//a[@title="home:Iggy:branches:kde4"]').has_text? "~:kde4"
  end

end
