# ==============================================================================
# 
#
class PackageAddFilePage < PackagePage
  

  # ============================================================================
  # (see WebPage#validate_page)
  #
  def validate_page
    super
    ps = @driver.page_source
    validate { ps.include? "Add File to #{@package} (Project #{@project})" }
    validate { ps.include? "Filename (taken from uploaded file if empty):" }
    validate { ps.include? "Upload from" }
  end
  

  # ============================================================================
  # (see WebPage#initialize)
  #
  def initialize web_driver, options={}
    super
    @url = $data[:url] + 
      "/package/add_file?package=#{@package}&project=#{CGI.escape(@project)}"
  end
  

  # ============================================================================
  # (see WebPage#initialize_ready)
  #
  def initialize_ready web_driver
    super
    @url = @driver.current_url
    assert @url.start_with? $data[:url] + "/package/add_file?"
  end
  
  
  # ============================================================================
  #
  def add_file file
    file[:expect]      ||= :success
    file[:name]        ||= ""
    file[:upload_from] ||= :local_file
    file[:upload_path] ||= ""
    
    assert [:local_file, :remote_url].include? file[:upload_from]
    
#    @driver[:id => "filename"].focus
    @driver[:id => "filename"].send_keys file[:name]
    css_select = "select#file_type "
    if file[:upload_from] == :local_file then
      @driver[css: css_select + "option[value='local']"].click
      #@driver[:id => "file"].focus
      @driver[:id => "file"].send_keys file[:upload_path]
    else
      @driver[css: css_select + "option[value='remote']"].click
      #@driver[:id => "file_url"].focus
      @driver[:id => "file_url"].send_keys file[:upload_path]
    end
    @driver[css: "div#content input[name='commit']"].click
    
    # get file's name from upload path in case it wasn't specified caller
    file[:name] = File.basename(file[:upload_path]) if file[:name] == ""
    
    if file[:expect] == :success
      assert_equal flash_message, "The file #{file[:name]} has been added."
      assert_equal flash_message_type, :info
      $page = PackageSourcesPage.new_ready @driver
      # TODO: Check that new file is in the list
    elsif file[:expect] == :no_path_given
      assert_equal flash_message_type, :alert 
      assert_equal flash_message, "No file or URI given."
    elsif file[:expect] == :invalid_upload_path
      assert_equal flash_message_type, :alert 
      # Currently the page goes to Inteface Error. Implement when bug is fixed.      
      validate_page
    elsif file[:expect] == :no_permission
      validate { flash_message_type == :alert }
      # Currently the page goes to Inteface Error. Implement when bug is fixed.  
      validate_page
    elsif file[:expect] == :download_failed
      # the _service file is added, but the download fails
      fm = flash_messages
      assert_equal fm.count, 2
      assert_equal fm[0], "The file #{file[:name]} has been added." 
      assert fm[1].include?("service download_url failed"), "expected '#{fm[1]}' to include 'Download failed'"
    else
      raise "Invalid value for argument expect."
    end
  end
  
  
end
