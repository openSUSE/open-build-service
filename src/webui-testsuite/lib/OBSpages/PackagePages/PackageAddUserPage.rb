# ==============================================================================
# 
#
class PackageAddUserPage < PackagePage


  # ============================================================================
  # (see WebPage#validate_page)
  #
  def validate_page
    super
    ps = @driver.page_source
    validate { ps.include?  "Add New User to #{@package} (Project #{@project})" }
    validate { ps.include? "User:" }
    validate { ps.include? "Role:" }
  end

  def initialize web_driver, options={}
    super
    @url = $data[:url] + "/package/add_person?project=" + CGI.escape(@project)
  end
  

  # ============================================================================
  # (see WebPage#initialize_ready)
  #
  def initialize_ready web_driver
    super
    @url = @driver.current_url
    assert @url.start_with? $data[:url] + "/package/add_person?"
  end
  
  
  # ============================================================================
  #
  def add_user user, role, options = {}
    options[:expect] ||= :success
    
    @driver[:id => 'userid'].clear
    @driver[:id => 'userid'].send_keys user.to_s
    @driver[:css => "select#role option[value=#{role}]"].click
    @driver[:id => 'userid'].submit
    
    if options[:expect] == :success
      validate { flash_message_type == :info }
      validate { flash_message == "Added user #{user} with role #{role}" }
      $page = PackageUsersPage.new_ready @driver
    elsif options[:expect] == :unknown_user
      @url += "&role=" + role unless @url.include? 'role='
      validate { flash_message_type == :alert }
      validate { flash_message == "Unknown user '#{user}'" }
      validate_page
    elsif options[:expect] == :invalid_username
      @url += "&role=" + role unless @url.include? 'role='
      validate { flash_message_type == :alert }
      validate { flash_message.strip == "Invalid username: #{user}".strip }
      validate_page
    else
      raise ArgumentError
    end
  end
  
  
end
