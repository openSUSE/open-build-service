# ==============================================================================
# Represents the page for creating new packages for a given project
# at OBS (/project/new_package)
#
class NewPackagePage < ProjectPage
  
  
  # ============================================================================
  # (see WebPage#validate_page)
  #
  def validate_page
    super
    validate { @driver.page_source.include? "Create New Package for " + project }
    validate { @driver.page_source.include? "Name:" }
    validate { @driver.page_source.include? "Title:" }
    validate { @driver.page_source.include? "Description:" }
    assert @url.start_with? $data[:url] + "/project/new_package?"
  end
  
  
  # ============================================================================
  # (see WebPage#initialize)
  #
  def initialize web_driver, options={}
    super
    @url = $data[:url] + "/project/new_package?project=" + CGI.escape(@project)
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
  def create_package new_package
    new_package[:expect]      ||= :success
    new_package[:name]        ||= ""
    new_package[:title]       ||= ""
    new_package[:description] ||= ""
 
    new_package[:description].squeeze!(" ")
    new_package[:description].gsub!(/ *\n +/ , "\n")
    new_package[:description].strip!
    message_prefix = "Package '#{new_package[:name]}' "
    
    @driver[:id => "name"].clear
    @driver[:id => "name"].send_keys new_package[:name]
    @driver[:id => "title"].clear
    @driver[:id => "title"].send_keys new_package[:title]
    @driver[:id => "description"].clear
    @driver[:id => "description"].send_keys new_package[:description]
    @driver[css: "div#content input[name='commit']"].click
 
    if new_package[:expect] == :success
      assert_equal flash_message, message_prefix + "was created successfully" 
      assert_equal flash_message_type, :info 
      $page = PackageOverviewPage.new_ready @driver
      new_package[:description] = "No description set" if new_package[:description].empty?
      assert_equal new_package[:description], $page.package_description 
    elsif new_package[:expect] == :invalid_name
      assert_equal flash_message, "Invalid package name: '#{new_package[:name]}'" 
      assert_equal flash_message_type, :alert
      validate_page
    elsif new_package[:expect] == :already_exists
      assert_equal flash_message, message_prefix + "already exists in project '#{@project}'" 
      assert_equal flash_message_type, :alert 
      validate_page
    else
      throw "Invalid value for argument expect(must be :success, :invalid_name, :already_exists)"
    end
  end


end
