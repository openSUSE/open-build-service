# ==============================================================================
# Represents user's projects page at OBS (/home/list_my)
#
class MyProjectsPage < BuildServicePage
  

  # ============================================================================
  # (see WebPage#validate_page)
  #
  def validate_page
    super
    validate { @driver.page_source.include? "My Projects" }
    validate { @driver.page_source.include? "Watched Projects" }
    validate { @driver.page_source.include? "Involved Projects" }
    validate { @driver.page_source.include? "Involved Packages" }   
  end
  

  # ============================================================================
  # (see WebPage#initialize)
  #
  def initialize web_driver, options={}
    super
    @url = $data[:url] + "/home/list_my"
  end
  

  # ============================================================================
  # (see WebPage#initialize_ready)
  #
  def initialize_ready web_driver
    super
    @url = $data[:url] + "/home/list_my"
  end

  def open_project project_name
    @driver[xpath: "//table[@id='involved_prj-table']//a[text()='#{project_name}']"].click
    $page = ProjectOverviewPage.new_ready @driver
  end
  
  # Returns an array containing the full names of all involved projects
  def involved_projects
    return [] if @driver.page_source.include? "Not involved in any project."
    @driver[:id => 'involved_prj-table'].text.split("\n") - ["Project Actions"]
  end
  
  # Returns an array containing the full names of all involved packages
  def involved_packages
    return [] if @driver.page_source.include? "Not involved in any package."
  end
  
  # Returns an array containing the full names of all watched projects
  def watched_projects
    return [] if @driver.page_source.include? "No projects marked to be watched."
    @driver[:id => 'watched_projects-table'].text.split("\n") - ["Project Actions"]
  end
  
end
