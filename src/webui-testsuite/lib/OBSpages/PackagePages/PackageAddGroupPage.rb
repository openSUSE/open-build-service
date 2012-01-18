# ==============================================================================
# 
#
class PackageAddGroupPage < PackagePage


  # ============================================================================
  # (see WebPage#validate_page)
  #
  def validate_page
    super
    validate { @driver.page_source.include? 
      "Add New Group to #{@package} (Project #{@project})" }
    validate { @driver.page_source.include? "Group:" }
    validate { @driver.page_source.include? "Role:" }
  end


  # ============================================================================
  # (see WebPage#initialize)
  #
  def initialize web_driver, options={}
    super
    @url = $data[:url] + "/package/add_group?project=" + CGI.escape(@project)
  end
  

  # ============================================================================
  # (see WebPage#initialize_ready)
  #
  def initialize_ready web_driver
    super
    @url = @driver.current_url
    assert @url.start_with? $data[:url] + "/package/add_group?"
  end
  
  
  # ============================================================================
  #
  def add_group group, role, options = {}
    options[:expect] ||= :success
    
    @driver[:id => 'groupid'].clear
    @driver[:id => 'groupid'].send_keys group.to_s
    @driver[:css => "select#role option[value=#{role}]"].click
    @driver[:id => 'groupid'].submit
    
    if options[:expect] == :success
      validate { flash_message_type == :info }
      validate { flash_message == "Added group #{group} with role #{role}" }
      $page = PackageUsersPage.new_ready @driver
    elsif options[:expect] == :unknown_group
      @url += "&role=" + role unless @url.include? 'role='
      validate { flash_message_type == :alert }
      validate { flash_message == "Unable to add unknown group '#{group}'" }
      validate_page
    else
      raise ArgumentError
    end
  end
  
  
end
