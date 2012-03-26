# ==============================================================================
# 
#
class PackageOverviewPage < PackagePage


  # ============================================================================
  # (see WebPage#validate_page)
  #
  def validate_page
    super
    assert @url.start_with? $data[:url] + "/package/show"
    validate { @driver.page_source.include? "Information" }
    validate { @driver.page_source.include? "Actions" }
    validate { @driver.page_source.include? "Build Results" }
  end
  

  # ============================================================================
  # (see WebPage#initialize)
  #
  def initialize web_driver, options={}
    super
    @url = $data[:url] + "/package/show"
    @url += "?package=#{CGI.escape(@package)}&project=#{CGI.escape(@project)}"
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
  def delete_package
    @driver[:xpath => "//div[@id='content']//a[text()='Delete package']"].click

    validate { @driver.include? :xpath => "//div[@id='dialog_wrapper']//b[text()='Delete Confirmation']" }
    
    @driver[:xpath => "//form[@action='/package/remove']//input[@name='commit'][@value='Ok']"].click
    
    msg = "Package '#{@package}' was removed successfully from project '#{@project}'"
    assert_equal flash_message, msg 
    assert_equal flash_message_type, :info
    
    $page = ProjectOverviewPage.new_ready @driver
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
  def package_title
    @driver[:id => "package_title"].text
  end
  
  
  # ============================================================================
  #
  def package_description
    @driver[:id => "description"].text
  end
  
  
  # ============================================================================
  #
  def change_package_info new_info
    assert (new_info[:title] or new_info[:description]) != nil

    @driver[:xpath => 
      "//div[@id='content']//a[text()='Edit description']"].click
    validate { @driver.page_source.include?(
      "Edit Package Information of #{@package} (Project #{@project})") }
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
    
    @driver[:xpath => "//form[@action='/package/save']//input[@name='commit'][@value='Save changes']"].click
    
    validate_page
    unless new_info[:title].nil?
      validate { package_title == new_info[:title] }
    end
    unless new_info[:description].nil?
      validate { package_description == new_info[:description] }
    end
    
  end


end
