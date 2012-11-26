# ==============================================================================
# Represents the All Projects Page at OBS (/project/list_public)
#
class AllProjectsPage < BuildServicePage
  

  # ============================================================================
  # (see WebPage#validate_page)
  #
  def validate_page
    super

  end
  

  # ============================================================================
  # (see WebPage#initialize)
  #
  def initialize web_driver, options={}
    super
    @url = $data[:url] + "/project/list_public"
  end
  

  # ============================================================================
  # (see WebPage#initialize_ready)
  #
  def initialize_ready web_driver
    super
    @url = $data[:url] + "/project/list_public"
  end
  
  def open_project project_name
    @driver[xpath: "//div[@id='project_list']//a[text()='#{project_name}']"].click
    $page = ProjectOverviewPage.new_ready @driver
  end
  
  def open_new_project
    @driver[css: "div#content a[href='/project/new']"].click
    $page=NewProjectPage.new_ready @driver
  end
end
