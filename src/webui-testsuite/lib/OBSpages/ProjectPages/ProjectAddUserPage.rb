# ==============================================================================
# 
#
class ProjectAddUserPage < ProjectPage


  # ============================================================================
  # (see WebPage#validate_page)
  #
  def validate_page
    super
    ps = @driver.page_source
    validate { ps.include? "Add New User to " + @project }
    validate { ps.include? "User:" }
    validate { ps.include? "Role:" }
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
      assert_equal flash_message_type, :info 
      assert_equal flash_message,
        "Added user #{user} with role #{role} to project #{@project}" 
      $page = ProjectUsersPage.new_ready @driver
    elsif options[:expect] == :unknown_user
      assert_equal flash_message_type, :alert 
      assert_equal flash_message, "Unknown user '#{user}'"
      validate_page
    elsif options[:expect] == :invalid_userid
      assert_equal flash_message_type, :alert
      assert_equal flash_message, "No valid user id given!"
      $page = ProjectUsersPage.new_ready @driver
    else
      raise ArgumentError
    end
  end
  
  
end
