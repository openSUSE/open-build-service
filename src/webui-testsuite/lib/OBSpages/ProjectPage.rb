# ==============================================================================
# Represents a common page for all project related pages in OBS. Contains
# functionality like tabs and validations.
# @abstract
#
class ProjectPage < BuildServicePage
  

  # ============================================================================
  # (see WebPage#validate_page)
  #
  def validate_page
    super
    validate { @project == project }
    if @available_tabs.has_value? self.class then
      assert_equal @available_tabs[selected_tab], self.class
    else
      assert_equal selected_tab, :none
    end
  end
  

  # ============================================================================
  # (see WebPage#initialize)
  #
  def initialize web_driver, options={}
    super
    @project = options[:project]
    @available_tabs = ALL_PROJECT_TABS
    @advanced_tabs  = ADVANCED_PROJECT_TABS
    assert @project != nil
  end
  

  # ============================================================================
  # (see WebPage#initialize_ready)
  #
  def initialize_ready web_driver
    super
    @project = project_namespace + project_name
    @available_tabs = ALL_PROJECT_TABS
    @advanced_tabs  = ADVANCED_PROJECT_TABS
  end
  
  ALL_PROJECT_TABS = { "Users"          => ProjectUsersPage,
                       "Project Config" => ProjectConfigPage,
                       "Status"         => ProjectStatusPage,
                       "Overview"       => ProjectOverviewPage,
                       "Packages"       => ProjectPackagesPage,
                       "Requests"       => ProjectRequestsPage,
                       "Meta"           => ProjectRawConfigPage,
                       "Attributes"     => ProjectAttributesPage,
                       "Subprojects"    => ProjectSubprojectsPage,
                       "Repositories"   => ProjectRepositoriesPage }
                     
  ADVANCED_PROJECT_TABS = [ "Project Config", "Status",
                            "Meta", "Attributes" ]  
             
  
  # ============================================================================
  #        
  def open_tab tab
    unless @available_tabs.include? tab
      puts "'#{tab}' not included in #{@available_tabs.inspect}"
    end
    assert @available_tabs.include? tab 
    
    tab_xpath = 
      "//div[@id='content']//div[@class='box-header header-tabs']//li/a" 
    if @advanced_tabs.include? tab then
      if @driver.include? :xpath => tab_xpath + "[text()='Advanced']" then
        @driver[ :xpath => tab_xpath + "[text()='Advanced']" ].click
        wait_for_javascript
      end
    end

    @driver[ :xpath => tab_xpath + "[text()='" + tab + "']" ].click
    wait_for_javascript
    $page =  @available_tabs[tab].new_ready @driver
  end
  
  
  # ============================================================================
  #
  def selected_tab
    tab_xpath  = "//ul[@id='project_tabs']//li[@class='selected']/a"
    results = @driver.find_elements :xpath => tab_xpath
    return results.first.text unless results.empty?
    return :none
  end
  
  
  # ============================================================================
  #
  def project
    project_namespace + project_name
  end
  
  
  # ============================================================================
  #
  def project_name
    assert @driver.current_url.include? "project="
    project = @driver.current_url.split("project=").last.split("&").first
    project.chop! if project.end_with? "#", "?", "%"
    project = CGI.unescape project
    project.split(":").last
  end
  
  
  # ============================================================================
  #
  def project_namespace
    assert @driver.current_url.include? "project="
    project = @driver.current_url.split("project=").last.split("&").first
    project = CGI.unescape project
    return "" unless project.include? ":"
    project[0, project.length - project.split(":").last.length]
  end
  
  
end
