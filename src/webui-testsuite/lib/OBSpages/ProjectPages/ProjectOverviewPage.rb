# ==============================================================================
# 
#
class ProjectOverviewPage < ProjectPage


  # ============================================================================
  # (see WebPage#validate_page)
  #
  def validate_page
    super
    ps = @driver.page_source
    validate { ps.include? "Packages" }
    validate { ps.include? "Build Results" }
  end


  # ============================================================================
  # (see WebPage#initialize)
  #
  def initialize web_driver, options = {}
    super
    @url = $data[:url] + "/project/show?project=" + CGI.escape(@project)
  end
  

  # ============================================================================
  # (see WebPage#initialize_ready)
  #
  def initialize_ready web_driver
    super
    @url = $data[:url] + "/project/show?project=" + CGI.escape(@project)
  end
  
  
  # ============================================================================
  #
  def delete_project options = {}
    @driver[id: 'delete-project'].click
    wait_for_javascript

    assert_equal @driver.find_element(css: 'div#dialog_wrapper h2').text, 'Delete Confirmation'
    @driver[css: "form[action='/project/delete'] input[name='commit']"].click
    wait_for_javascript
    
    assert_equal flash_message, "Project '#{@project}' was removed successfully" 
    assert_equal flash_message_type, :info 
    
    @user[:created_projects].delete @project
    if options[:newproject]
       @project = options[:newproject]
       @url = $data[:url] + "/project/show?project=" + CGI.escape(@project)
       $page = ProjectOverviewPage.new_ready @driver
    else
       $page = AllProjectsPage.new_ready @driver
    end
  end
  
  
  # ============================================================================
  #
  def request_deletion description
    @driver[id: 'request-deletion'].click
    wait_for_javascript
      
    assert_equal @driver.find_element(css: 'div#dialog_wrapper h2').text, 'Create Delete Request'
    
    @driver[:id => "description"].clear
    @driver[:id => "description"].send_keys description
      
    @driver[css: "form[action='/request/delete_request?method=post'] input[@name='commit']"].click
    wait_for_javascript
      
    $page = RequestDetailsPage.new_ready @driver
  end
  
  
  # ============================================================================
  #  
  def project_title
    @driver[:id => "project_title"].text
  end
  
  
  # ============================================================================
  # Returns the description of the viewed project as is displayed.
  # Caller should keep in mind that multi-space / multi-line text
  # will probably get trimmed and stripped when displayed.
  #
  def project_description
    @driver[:id => "description"].text
  end
  
  
  # ============================================================================
  #
  def open_create_subproject
    @driver[id: 'link-create-subproject'].click
    wait_for_javascript
    $page = NewProjectPage.new_ready @driver
  end


  # ============================================================================
  #
  def open_new_package
    @driver[xpath: "//*[@id='content']//*[text()='Create package']"].click
    wait_for_javascript
    $page = NewPackagePage.new_ready @driver
  end


  # ============================================================================
  #
  def open_branch_package
    @driver[xpath: "//*[@id='content']//*[text()='Branch existing package']"].click
    wait_for_javascript
    $page = NewPackageBranchPage.new_ready @driver
  end
  
  
  # ============================================================================
  # Changes project's title and/or description.
  # Expects arguments grouped into a hash.
  #
  def change_project_info new_info
    assert (new_info[:title] or new_info[:description]) != nil
    
    @driver[xpath: "//*[@id='content']//*[text()='Edit description']"].click
    wait_for_javascript
    validate { @driver.page_source.include?( "Edit Project Information of " + project) }
    validate { @driver.page_source.include? "Title:" }
    validate { @driver.page_source.include? "Description:" }
    
    unless new_info[:title].nil?
      @driver[:id => "title"].clear
      @driver[:id => "title"].send_keys new_info[:title]
    end
      
    unless new_info[:description].nil?
      new_info[:description].squeeze!(" ")
      new_info[:description].gsub!(/ *\n +/ , "\n")
      new_info[:description].strip!
      @driver[:id => "description"].clear
      @driver[:id => "description"].send_keys new_info[:description]
    end
    
    @driver[css: "form[action='/project/save'] input[name='commit']"].click
    wait_for_javascript

    validate_page
    unless new_info[:title].nil?
      validate { project_title == new_info[:title] }
    end
    unless new_info[:description].nil?
      validate { project_description == new_info[:description] }
    end
    
  end
  
end
