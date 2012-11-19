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
    
    textarea = nil
    wait.until {
      # we need to click into the code block before we can send keys - tricky!
      codelines = @driver[:css => ".CodeMirror-lines"]
      codelines.click if codelines
      textarea = @driver[:css => ".CodeMirror textarea"]
      textarea.displayed?
    }
    savebutton = @driver.find_element(:css => "a.save")
    assert savebutton["class"].split(" ").include? "inactive"
    
    textarea.send_keys([:control, 'a'])
    textarea.send_keys([:control, 'x'])
    textarea.send_keys new_content
    wait.until {
      !savebutton["class"].split(" ").include? "inactive"
    }
 #   @driver[:css => "div#content input#comment"].clear
 #   @driver[:css => "div#content input#comment"].send_keys commit_message

    assert !savebutton["class"].split(" ").include?("inactive")
    @driver[:css => "a.save"].click
    wait_for_javascript
    wait.until {
      savebutton["class"].split(" ").include? "inactive"
    }
#    assert_equal flash_message, "Successfully saved file #{@file}"
#    assert_equal flash_message_type, :info 
    
    # does not leave
    # $page = PackageOverviewPage.new_ready @driver
  end
  
  
end
