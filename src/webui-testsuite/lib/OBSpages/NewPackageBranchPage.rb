# ==============================================================================
# Represents the page for creating new package branches for a given package
# at OBS (/project/new_package_branch)
#
class NewPackageBranchPage < ProjectPage
    

  # ============================================================================
  # (see WebPage#validate_page)
  #
  def validate_page
    super
    ps = @driver.page_source
    validate { ps.include? "Add New Package Branch to " + project }
    validate { ps.include? "Name of original project:" }
    validate { ps.include? "Name of package in original project:" }
    validate { ps.include? "Name of branched package in target project:" }
    assert @url.start_with? $data[:url] + "/project/new_package_branch?"
  end
    

  # ============================================================================
  # (see WebPage#initialize)
  #
  def initialize web_driver, options={}
    super
    @url = $data[:url] + "/project/new_package_branch?project=" + CGI.escape(@project)
  end
    

  # ============================================================================
  # (see WebPage#initialize_ready)
  #
  def initialize_ready web_driver
    super
    @url = @driver.current_url
  end
  
  
  # ============================================================================
  #
  def create_package_branch new_branch
    new_branch[:expect]           ||= :success
    new_branch[:name]             ||= ""
    new_branch[:original_name]    ||= ""
    new_branch[:original_project] ||= ""

    @driver[:id => "linked_project"].clear
    @driver[:id => "linked_project"].send_keys new_branch[:original_project]
    @driver[:id => "linked_package"].clear
    @driver[:id => "linked_package"].send_keys new_branch[:original_name]
    @driver[:id => "target_package"].clear
    @driver[:id => "target_package"].send_keys new_branch[:name]
    @driver[css: "div#content input[name='commit']"].click

    if new_branch[:expect] == :success
      assert_equal flash_message, "Branched package #{@project} / #{new_branch[:name]}" 
      assert_equal flash_message_type, :info 
      $page = PackageOverviewPage.new_ready @driver
      #???
    elsif new_branch[:expect] == :invalid_package_name
      validate { flash_message == "Invalid package name: '#{new_branch[:original_name]}'" }
      validate { flash_message_type == :alert }
      validate_page
    elsif new_branch[:expect] == :invalid_project_name
      validate { flash_message == "Invalid project name: '#{new_branch[:original_project]}'" }
      validate { flash_message_type == :alert }
      validate_page
    elsif new_branch[:expect] == :already_exists
      validate { flash_message == 
        "Package '#{new_branch[:name]}' already exists in project '#{@project}'" }
      validate { flash_message_type == :alert }
      validate_page
    else
      throw "Invalid value for argument <expect>."
    end
  end
  

end
