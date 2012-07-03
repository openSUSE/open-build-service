# ==============================================================================
# Represents the All Projects Page at OBS (/project/list_public)
#
class AllProjectsPage < BuildServicePage
  

  # ============================================================================
  # (see WebPage#validate_page)
  #
  def validate_page
    super
    validate { @driver.page_source.include? "Public Projects" }
    validate { @driver.page_source.include? "Filter projects:" }
    validate { @driver.page_source.include? "Exclude user home projects" }
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
  
  def filter_projects filter_options
    pattern = filter_options[:pattern]
    exclude_home_projects = filter_options[:exclude_home_projects]
    assert pattern != nil || exclude_home_projects != nil
    
    unless exclude_home_projects.nil?
      current_state = @driver[:id => "excludefilter"].selected?
      @driver[:id => "excludefilter"].click unless current_state == exclude_home_projects
    end
    
    unless pattern.nil?
      @driver[:id => "searchtext"].clear       
      @driver[:id => "searchtext"].send_keys pattern.to_s
      @driver[:id => "searchtext"].send_keys :enter

      @url = $data[:url] + "/project/list?utf8=%E2%9C%93&searchtext=#{pattern}"
    end
    
  end
  
  def current_project_filter
    pattern       = @driver[:id => "searchtext"].attribute "value"
    home_projects = @driver[:id => "excludefilter"].attribute("checked") == "true"
    Hash[:pattern => pattern, :exclude_home_projects => home_projects]
  end
  
  def displayed_projects
    results = []
    @driver[:id => "project_list"].text.split("|").each do |element|
      next if element.include? "All Projects"
      next if element.include? "All Public Projects"
      next if element.include? "No projects found"
      if element.include? "\n" then
        results << element.split("\n").first.strip
      else
        results << element.strip
      end
    end
    results 
  end
  
 def open_project project_name
    @driver[:xpath => "//div[@id='project_list']//a[text()='#{project_name}']"].click
    $page = ProjectOverviewPage.new_ready @driver
  end
  
  def open_new_project
    @driver[:xpath => "//div[@id='content']//a[@href='/project/new']"].click
    $page=NewProjectPage.new_ready @driver
  end
end
