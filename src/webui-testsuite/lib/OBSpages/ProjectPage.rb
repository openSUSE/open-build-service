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
    st = selected_tab
    if @available_tabs.has_value? self.class then
      assert st != :none && !st.empty?, "no tab in #{@tabs_id} selected"
      assert_equal @available_tabs[st], self.class
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
    @tabs_id = 'project_tabs'
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
    @tabs_id = 'project_tabs'
  end
  
  ALL_PROJECT_TABS = { "Users"          => ProjectUsersPage,
                       "Project Config" => ProjectConfigPage,
                       "Status"         => ProjectStatusPage,
                       "Overview"       => ProjectOverviewPage,
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
      "//div[@id='#{@tabs_id}']//li/a" 
    if @advanced_tabs.include? tab
      trigger = @driver.find_elements(:css => "#advanced_tabs_trigger")
      if !trigger.first.nil? && trigger.first.displayed?
        trigger.first.click
	wait.until do
          t = @driver.find_element( :xpath => tab_xpath + "[text()='#{tab}']" ) 
	  t && t.displayed?
      end
      end
    end

    @driver[ :xpath => tab_xpath + "[text()='#{tab}']" ].click
    $page =  @available_tabs[tab].new_ready @driver
  end
  
  
  # ============================================================================
  #
  def selected_tab
    tab_xpath  = ".//li[@class='selected']/a"
    results = @driver[:id => @tabs_id].find_elements :xpath => tab_xpath
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
