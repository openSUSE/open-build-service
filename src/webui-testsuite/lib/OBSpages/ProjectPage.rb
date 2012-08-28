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
  
  ALL_PROJECT_TABS = { "users"          => ProjectUsersPage,
                       "projectconfig"  => ProjectConfigPage,
                       "status"         => ProjectStatusPage,
                       "overview"       => ProjectOverviewPage,
                       "requests"       => ProjectRequestsPage,
                       "meta"           => ProjectRawConfigPage,
                       "attributes"     => ProjectAttributesPage,
                       "subprojects"    => ProjectSubprojectsPage,
                       "repositories"   => ProjectRepositoriesPage }
                     
  ADVANCED_PROJECT_TABS = [ "projectconfig", "status",
                            "meta", "attributes" ]  
             
  
  # ============================================================================
  #        
  def open_tab tab
    unless @available_tabs.include? tab
      puts "'#{tab}' not included in #{@available_tabs.inspect}"
    end
    assert @available_tabs.include? tab 
    
    if @advanced_tabs.include? tab
      trigger = @driver.find_elements(:css => "#advanced_tabs_trigger")
      if !trigger.first.nil? && trigger.first.displayed?
        trigger.first.click
	wait.until do
          t = @driver.find_element( id: "tab-#{tab}" ) 
	  t && t.displayed?
      end
      end
    end

    @driver[ css: "li#tab-#{tab} a" ].click
    $page =  @available_tabs[tab].new_ready @driver
  end
  
  
  # ============================================================================
  #
  def selected_tab
    results = @driver[:id => @tabs_id].find_elements css: "li.selected"
    return :none if results.empty?
    id = results.first.attribute('id')
    id.gsub(%r{tab-},'')
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
