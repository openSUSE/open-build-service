# ==============================================================================
# 
#
class SearchResultsPage < BuildServicePage
    

  # ============================================================================
  # (see WebPage#validate_page)
  #
  def validate_page
    super
    if @search_text != ""
      search_details = "for \"#{@search_text}\""
      if @search_attribute != ""
        search_details += " with \"#{@search_attribute}\""
      end
    else
      search_details = "with attribute \"#{@search_attribute}\""
    end
    found_text = @driver[:css => "div#content h3"].text
    assert found_text =~ /^Search Results #{search_details}\s+\(\d+\)$/, 
           "'#{found_text}' did not match /^Search Results #{search_details}\s+\(\d+\)$/"
  end
  

  # ============================================================================
  # (see WebPage#initialize)
  #
  def initialize web_driver, options={}
    super
    @url = @driver.current_url #TODO make self creator
    @search_text = options[:text]
  end
  

  # ============================================================================
  # (see WebPage#initialize_ready)
  #
  def initialize_ready web_driver
    super
    @url = @driver.current_url
    if @driver.current_url.include? "search_text="
      @search_text = @driver.current_url.split("search_text=").last.split("&").first
      @search_text = CGI.unescape @search_text
    else
      @search_text = ""
    end
    if @driver.current_url.include? "attribute="
      @search_attribute = @driver.current_url.split("attribute=").last.split("&").first
      @search_attribute = CGI.unescape @search_attribute
    else
      @search_attribute = ""
    end
  end
  
end
