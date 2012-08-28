class GroupIndexPage < BuildServicePage

  # ============================================================================
  # (see WebPage#validate_page)
  #
  def validate_page
    super
    ps = @driver.page_source
    validate { ps.include? "Groups" }
  end
  

  # ============================================================================
  # (see WebPage#initialize)
  #
  def initialize web_driver, options={}
    super
    @url = $data[:url] + "/groups"
  end
  

  # ============================================================================
  # (see WebPage#initialize_ready)
  #
  def initialize_ready web_driver
    super
    @url = $data[:url] + "/groups"
  end


  # ============================================================================
  # Click on first group link
  #
  def open_first_group
    @driver.find_elements(css: "table#group_table a").each do |link|
      if link.attribute("href").start_with?($data[:url] + "/groups")
         link.click
	 $page = GroupShowPage.new_ready @driver
	 return
      end
    end
    assert false
  end
  
end

