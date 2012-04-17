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
    #@driver[:xpath => "//div[@id='content']//tbody/tr[0]/td[0]/a"].click
    @driver[:xpath => "//table[@id='group_table']//a[starts-with(@href,'/groups/')]"].click
    $page = GroupShowPage.new_ready @driver
  end
  
end

