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
    validate { @driver.page_source.include? "Source Files" }
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
    @driver[id: 'delete-package'].click
    wait_for_javascript

    assert_equal @driver[css: "div#dialog_wrapper h2"].text, 'Delete Confirmation'
    
    @driver[css: "form[action='/package/remove'] input[name='commit']"].click
    
    msg = "Package '#{@package}' was removed successfully from project '#{@project}'"
    $page = ProjectOverviewPage.new_ready @driver
    assert_equal flash_message, msg 
    assert_equal flash_message_type, :info
  end
  
  
  # ============================================================================
  #
  def request_deletion description
    @driver[xpath: "//*[@id='content']//*[text()='Request deletion']"].click
    wait_for_javascript 
      
    assert_equal @driver[css: "div#dialog_wrapper b"].text, 'Create Delete Request'
    
    @driver[:id => "description"].clear
    @driver[:id => "description"].send_keys description
      
    @driver[css: "form[action='/request/delete_request?method=post'] input[name='commit']"].click
    
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

    @driver[id: "edit-description"].click
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
    
    @driver[css: "form[action='/package/save'] input[name='commit']"].click
    
    validate_page
    unless new_info[:title].nil?
      validate { package_title == new_info[:title] }
    end
    unless new_info[:description].nil?
      validate { package_description == new_info[:description] }
    end
    
  end

  # ============================================================================
  #
  def open_add_file
    @driver[xpath: "//*[@id='content']//*[text()='Add file']"].click
    $page=PackageAddFilePage.new_ready @driver
  end
  
  
  # ============================================================================
  #
  def open_file file
    @driver[css: "tr##{valid_xml_id('file-' + file)} td:first-child a"].click
    $page = PackageEditFilePage.new_ready @driver
  end

end
