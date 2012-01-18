# ==============================================================================
# 
#
class ProjectPackagesPage < ProjectPage


  # ============================================================================
  # (see WebPage#validate_page)
  #
  def validate_page
    super
    validate { @driver.page_source.include? "Packages of " + @project }
  end
  

  # ============================================================================
  # (see WebPage#initialize)
  #
  def initialize web_driver, options={}
    super
    @url = $data[:url] + "/project/packages?project=" + CGI.escape(@project)
  end
  

  # ============================================================================
  # (see WebPage#initialize_ready)
  #
  def initialize_ready web_driver
    super
    @url = $data[:url] + "/project/packages?project=" + CGI.escape(@project)
  end
  
  
  # ============================================================================
  #
  def open_new_package
    @driver[:xpath => "//div[@id='content']//a[text()='Create package']"].click
    $page = NewPackagePage.new_ready @driver
  end
  
  
  # ============================================================================
  #
  def open_branch_package
    @driver[:xpath => "//div[@id='content']//a[text()='Branch package from other project']"].click
    $page = NewPackageBranchPage.new_ready @driver
  end


end
