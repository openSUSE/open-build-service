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
    validate { ps.include? "Information" }
    validate { ps.include? "Actions" }
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
    @driver[:xpath => 
      "//div[@id='content']//a[text()='Delete project']"].click

    validate { @driver.include? :xpath => "//div[@id='dialog_wrapper']//h2[text()='Delete Confirmation']" }
    @driver[:xpath => "//form[@action='/project/delete']//input[@name='commit'][@value='Ok']"].click
    
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
    @driver[:xpath => 
      "//div[@id='content']//a[text()='Request deletion']"].click
      
    validate { @driver.include? :xpath => 
      "//div[@id='dialog_wrapper']//b[text()='Create Delete Request']" }
    
    @driver[:id => "description"].clear
    @driver[:id => "description"].send_keys description
      
    @driver[:xpath => "//form[@action='/request/delete_request?method=post']
      //input[@name='commit'][@value='Ok']"].click
      
    $page = RequestDetailsPage.new_ready @driver
  end
  
  
  # ============================================================================
  #  
  def project_title
    @driver[:xpath => "//div[@id='content']//h3"].text
  end
  
  
  # ============================================================================
  # Returns the description of the viewed project as is displayed.
  # Caller should keep in mind that multi-space / multi-line text
  # will probably get trimmed and stripped when displayed.
  #
  def project_description
    @driver[:xpath => "//div[@id='content']//p"].text
  end
  
  
  # ============================================================================
  #
  def open_create_subproject
    @driver[:xpath => 
      "//div[@id='content']//a[text()='Create subproject']"].click
    $page = NewProjectPage.new_ready @driver

  end
  
  
  # ============================================================================
  # Changes project's title and/or description.
  # Expects arguments grouped into a hash.
  #
  def change_project_info new_info
    assert (new_info[:title] or new_info[:description]) != nil
    
    @driver[:xpath => "//div[@id='content']//a[text()='Edit description']"].click
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
    
    @driver[:xpath => "//form[@action='/project/save']//input[@name='commit'][@value='Save changes']"].click
    
    validate_page
    unless new_info[:title].nil?
      validate { project_title == new_info[:title] }
    end
    unless new_info[:description].nil?
      validate { project_description == new_info[:description] }
    end
    
  end
  
end
