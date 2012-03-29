# ==============================================================================
# 
#
class PackageEditFilePage < PackagePage
  

  # ============================================================================
  # (see WebPage#validate_page)
  #
  def validate_page
    super
    ps = @driver.page_source
    validate { ps.include? "File #{@file} of Package #{@package}" }
  end
  

  # ============================================================================
  # (see WebPage#initialize)
  #
  def initialize web_driver, options={}
    super
    @file = options[:file]
    @url = $data[:url] + "/package/view_file?"
    @url += "file=#{@file}&package=#{@package}&project=#{CGI.escape(@project)}"
  end
  

  # ============================================================================
  # (see WebPage#initialize_ready)
  #
  def initialize_ready web_driver
    super
    @file = CGI.unescape @driver.current_url.split("file=").last.split("&").first
    @url = @driver.current_url
    assert @url.start_with? $data[:url] + "/package/view_file?"
  end
  
  
  # ============================================================================
  #
  def current_file
    @driver[:css => "div#content table td.code"].text
  end
  
  
  # ============================================================================
  #
  def edit_file new_content, commit_message = ""
    # new edit page does not allow comments
 #   validate { @driver.page_source.include? "Comment your changes (optional):" }
    
    assert @driver.find_element(:css => "a.save")["class"].split(" ").include? "inactive"
    @driver[:css => "div.CodeMirror textarea"].clear
    Selenium::WebDriver::Wait.new(:timeout => 6, :interval => 0.1).until {
      puts "cleared", @driver.find_element(:css => "a.save")["class"]
      !@driver.find_element(:css => "a.save")["class"].split(" ").include? "inactive"
    }

    @driver[:css => "div.CodeMirror textarea"].send_keys new_content
    Selenium::WebDriver::Wait.new(:timeout => 6, :interval => 0.1).until {
      puts "after new ", @driver.find_element(:css => "a.save")["class"]
      !@driver.find_element(:css => "a.save")["class"].split(" ").include? "inactive"
    }
 #   @driver[:css => "div#content input#comment"].clear
 #   @driver[:css => "div#content input#comment"].send_keys commit_message

    assert !@driver.find_element(:css => "a.save")["class"].split(" ").include?("inactive")
    @driver[:css => "a.save"].click
    
    Selenium::WebDriver::Wait.new(:timeout => 6, :interval => 0.1).until {
	    puts @driver.find_element(:css => "a.save")["class"]
      @driver.find_element(:css => "a.save")["class"].split(" ").include? "inactive"
    }
#    assert_equal flash_message, "Successfully saved file #{@file}"
#    assert_equal flash_message_type, :info 
    
    # does not leave
    # $page = PackageSourcesPage.new_ready @driver
  end
  
  
end
