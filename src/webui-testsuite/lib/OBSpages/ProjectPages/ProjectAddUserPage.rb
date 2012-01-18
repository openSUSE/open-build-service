# ==============================================================================
# 
#
class ProjectAddUserPage < ProjectPage


  # ============================================================================
  # (see WebPage#validate_page)
  #
  def validate_page
    super
    validate { @driver.page_source.include? "Add New User to " + @project }
    validate { @driver.page_source.include? "User:" }
    validate { @driver.page_source.include? "Role:" }
  end


  # ============================================================================
  # (see WebPage#validate_page)
  #
  def initialize web_driver, options={}
    super
    @url = $data[:url] + "/project/add_person?project=" + CGI.escape(@project)
  end
  

  # ============================================================================
  # (see WebPage#validate_page)
  #
  def initialize_ready web_driver
    super
    @url = @driver.current_url
    assert @url.start_with? $data[:url] + "/project/add_person?"
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
      validate { flash_message == 
        "Added user #{user} with role #{role} to project #{@project}" }
      $page = ProjectUsersPage.new_ready @driver
    elsif options[:expect] == :unknown_user
      @url += "&role=" + role unless @url.include? 'role='
      validate { flash_message_type == :alert }
      validate { flash_message == "Unknown user with id '#{user}'" }
      validate_page
    else
      raise ArgumentError
    end
  end
  
  
end
