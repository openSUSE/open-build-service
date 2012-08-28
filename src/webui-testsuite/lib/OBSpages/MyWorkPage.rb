# ==============================================================================
# Represents user's work page at OBS (/home/my_work)
#
class MyWorkPage < BuildServicePage
  

  # ============================================================================
  # (see WebPage#validate_page)
  #
  def validate_page
    super
    validate { @driver.page_source.include? "My Work" }
    validate { @driver.page_source.include? "Open Reviews" }
    validate { @driver.page_source.include? "New Requests" } 
  end
  

  # ============================================================================
  # (see WebPage#initialize)
  #
  def initialize web_driver, options={}
    super
    @url = $data[:url] + "/home/my_work"
  end
  

  # ============================================================================
  # (see WebPage#initialize_ready)
  #
  def initialize_ready web_driver
    super
    @url = $data[:url] + "/home/my_work"
  end
  
  
  # ============================================================================
  #
  def new_requests
    row_xpath = "//table[@id='new_requests_table']//tr"
    number_of_requests = @driver.find_elements(xpath: row_xpath).count
    
    results = []
    for i in 2..number_of_requests
      request = {
        :source    => @driver[xpath: "#{row_xpath}[#{i}]/td[2]"].text,
        :target    => @driver[xpath: "#{row_xpath}[#{i}]/td[3]"].text,
        :requester => @driver[xpath: "#{row_xpath}[#{i}]/td[4]"].text,
        :type      => @driver[xpath: "#{row_xpath}[#{i}]/td[5]"].text,
        :state     => @driver[xpath: "#{row_xpath}[#{i}]/td[6]"].text }
      results << request
    end
    
    return results
  end

  
  # ============================================================================
  #
  def open_request row
    @driver[xpath: "//table[@id='new_requests_table']//tr[#{row+2}]/td[7]/a"].click
    $page = RequestDetailsPage.new_ready @driver
  end
  
  
end
