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
  
  
  # ============================================================================
  #
  def search_results
    raw_results = @driver.find_elements css: "table#search_result tr"
    raw_results.collect do |row|
      alt = row.find_element(css: "img").attribute("alt")
      case alt
        when "Project"
          { :type         => :project, 
            :project_name => row.find_element(css: "a").text }
        when "Package"
          { :type         => :package, 
            :package_name => row.find_elements(css: "a").first.text,
            :project_name => row.find_elements(css: "a").last.text }
        else
          fail "Unrecognized result icon. #{alt}"
      end
    end
  end
  
  
  # ============================================================================
  #
  def open_result result
    if result.is_a? Hash
      assert search_results.include? result
      index = search_results.index(result) + 1
    elsif result.is_a? Integer
      assert search_results.count >= result
      index = result
      result = search_results[index-1]
    else
      raise ArgumentError
    end
    
    @driver.find_elements(css: "table#search_result tr")[index].find_element(css: "a").click
    if result[:type] == :project  then
      $page = ProjectOverviewPage.new_ready @driver
    else
      $page = PackageOverviewPage.new_ready @driver
    end
  end
  
  
end
