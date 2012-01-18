# ==============================================================================
# 
#
class StatusMonitorPage < BuildServicePage
  

  # ============================================================================
  # (see WebPage#validate_page)
  #
  def validate_page
    super
    validate { @driver.page_source.include? "Scheduler Status" }
    validate { @driver.page_source.include? "Workers" }
    validate { @driver.page_source.include? "Statistical Plots" }
  end
  

  # ============================================================================
  # (see WebPage#initialize)
  #
  def initialize web_driver, options={}
    super
    @url = $data[:url] + "/monitor"
  end
  

  # ============================================================================
  # (see WebPage#initialize_ready)
  #
  def initialize_ready web_driver
    super
    @url = $data[:url] + "/monitor"
  end
  
end
