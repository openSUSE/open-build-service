class GroupShowPage < BuildServicePage
    

  # ============================================================================
  # (see WebPage#validate_page)
  #
  def validate_page
    super
    ps = @driver.page_source
    validate { ps.include? "Group #{@group}" }
  end
  

  # ============================================================================
  # (see WebPage#initialize)
  #
  def initialize web_driver, options={}
    super
    @url = @driver.current_url
    assert @url.start_with? $data[:url] + "/groups/"
    @group = @url.split('/groups/')[1]
  end
  

  # ============================================================================
  # (see WebPage#initialize_ready)
  #
  def initialize_ready web_driver
    super
    @url = @driver.current_url
    assert @url.start_with? $data[:url] + "/groups/"
    @group = @url.split('/groups/')[1]
  end


  # ============================================================================
  # Click on first user link
  #
  def open_first_user
    @driver[:xpath => "//table[@id='group_members_table']//a[starts-with(@href,'/home?user=')]"].click
    #$page = UserHomePage.new_ready @driver
  end
  
end
