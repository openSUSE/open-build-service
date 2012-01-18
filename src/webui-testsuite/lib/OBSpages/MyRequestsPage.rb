# ==============================================================================
# Represents user's requests page at OBS (/home/list_requests)
#
class MyRequestsPage < BuildServicePage


  # ============================================================================
  # (see WebPage#validate_page)
  #
  def validate_page
    super
    validate { @driver.page_source.include? "My Requests" }
    validate { @driver.page_source.include? "Display" }
    validate { @driver.page_source.include? "requests in state" }
  end
    

  # ============================================================================
  # (see WebPage#initialize)
  #
  def initialize web_driver, options={}
    super
    @url = $data[:url] + "/home/list_requests"
  end
    

  # ============================================================================
  # (see WebPage#initialize_ready)
  #
  def initialize_ready web_driver
    super
    @url = $data[:url] + "/home/list_requests"
  end
  
end
