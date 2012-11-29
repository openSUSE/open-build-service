# ==============================================================================
# Represents the greeter page at OBS.
#
class MainPage < BuildServicePage
  

  # ============================================================================
  # (see WebPage#validate_page)
  #
  def validate_page
    super
    validate { @driver.page_source.include? "Welcome to Open Build Service" }
  end
  

  # ============================================================================
  # (see WebPage#initialize)
  #
  def initialize web_driver, options={}
    super
    @url = $data[:url]
  end
  

  # ============================================================================
  # (see WebPage#initialize_ready)
  #
  def initialize_ready web_driver
    super
    @url = $data[:url]
  end
  
  def open_status_monitor
    @driver[css: "div#content a[href='/monitor']"].click
    $page=StatusMonitorPage.new_ready @driver
  end
  
  def open_all_projects
    @driver[css: "div#content a[href='/project/list_public']"].click
    $page=AllProjectsPage.new_ready @driver
  end
  
  def open_my_projects
    @driver[css: "div#content a[href='/home/list_my']"].click
    $page=MyProjectsPage.new_ready @driver
  end
  
  def open_new_project
    @driver[css: "#proceed-document-new a"].click
    $page=NewProjectPage.new_ready @driver
  end

end
