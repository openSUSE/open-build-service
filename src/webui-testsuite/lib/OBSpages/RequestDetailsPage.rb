# ==============================================================================
# 
#
class RequestDetailsPage < BuildServicePage


  # ============================================================================
  # (see WebPage#validate_page)
  #
  def validate_page
    super
    assert @url.start_with? $data[:url] + "/request/show/"
  end
  

  # ============================================================================
  # (see WebPage#initialize)
  #
  def initialize web_driver, options={}
    super
    @request_id = options[:request_id]
    assert (@request_id.is_a? Integer) and (@request_id.to_i > 0)
    @url = $data[:url] + "/request/show/" + @request_id
  end


  # ============================================================================
  # (see WebPage#initialize_ready)
  #
  def initialize_ready web_driver
    super
    @url = @driver.current_url
    @request_id = @url.split("/request/show/").last
  end


  # ============================================================================
  #
  def accept_request
    @driver[xpath: "//div[@id='content']//input[@name='accepted'][@value='Accept request']"].click

    validate { flash_message == "Request accepted!" }
    validate { flash_message_type == :info }
  end


end
