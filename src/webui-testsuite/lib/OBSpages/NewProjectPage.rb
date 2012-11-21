# ==============================================================================
# Represents the page for creating new projects for a given user
# at OBS (/project/new)
#
class NewProjectPage < BuildServicePage
  
  
  # ============================================================================
  # (see WebPage#validate_page)
  #
  def validate_page
    super
    ps = @driver.page_source
    validate do
      
      ps.include?("Create New Subproject") ||
      ps.include?("Create New Project") ||
      ps.include?("Your home project doesn't exist yet. You can create it now")
    end
    validate { ps.include? "Project Name:" }
    validate { ps.include? "Title:" }
    validate { ps.include? "Description:" }
    assert @url.start_with? $data[:url] + "/project/new"  # MOVE THIS
    validate { project_namespace == @namespace }
  end
  
  
  # ============================================================================
  # (see WebPage#initialize)
  #
  def initialize web_driver, options={}
    super
    @namespace = options[:namespace] || ""
    assert @user != :none
    @url = $data[:url] + "/project/new"
    unless @namespace == ""
      namespace = @namespace.clone
      namespace.chop! if namespace.end_with? ":"
      @url += "?ns=#{CGI.escape(namespace)}"
    end
  end
  
  
  # ============================================================================
  # (see WebPage#initialize_ready)
  #
  def initialize_ready web_driver
    super
    @url = @driver.current_url
    @namespace = project_namespace
  end
  
  
  # ============================================================================
  # Returns true if the user is required to create new home project.
  #
  def creating_home_project?
    @driver.page_source.include? "Your home project doesn't exist yet. You can create it now"
  end
  
  
  # ============================================================================
  # Returns the namespace of new project. In case of home project it
  # returns "home:". In case of global project it returns an empty string
  #
  def project_namespace
    return "home:" if creating_home_project?
    return "" unless @driver.current_url.include? "?ns="
    return CGI.unescape(@driver.current_url.split("?ns=").last + ":")
  end
  
  
  def create_project new_project
    new_project[:expect]      ||= :success
    new_project[:title]       ||= ""
    new_project[:description] ||= ""
    new_project[:maintenance] ||= false
    new_project[:hidden]      ||= false
    new_project[:namespace]     = project_namespace
    
    if creating_home_project? then
      new_project[:name] ||= current_user[:login]
      assert_equal new_project[:name], current_user[:login]
    else
      new_project[:name] ||= ""
      @driver[:id => "name"].clear
      @driver[:id => "name"].send_keys new_project[:name]
    end
        
    new_project[:description].squeeze!(" ")
    new_project[:description].gsub!(/ *\n +/ , "\n")
    new_project[:description].strip!
    message_prefix = "Project '#{new_project[:namespace] + new_project[:name]}' "

    @driver[:id => "title"].clear
    @driver[:id => "title"].send_keys new_project[:title]
    @driver[:id => "description"].clear
    @driver[:id => "description"].send_keys new_project[:description]
    @driver[:id => "maintenance_project"].click if new_project[:maintenance]
    @driver[:id => "access_protection"].click if new_project[:access_protection]
    @driver[css: "div#content input[name='commit']"].click
    
    if new_project[:expect] == :success
      assert_equal flash_message, message_prefix + "was created successfully"
      assert_equal flash_message_type, :info 
      $page = ProjectOverviewPage.new_ready @driver
      new_project[:description] = "No description set" if new_project[:description].empty?
      assert_equal CGI::escapeHTML(new_project[:description]), $page.project_description
      current_user[:created_projects] << new_project[:namespace] + new_project[:name]
    elsif new_project[:expect] == :invalid_name
      validate { flash_message == "Invalid project name '#{new_project[:name]}'." }
      validate { flash_message_type == :alert }
      validate_page
    elsif new_project[:expect] == :no_permission
      # namespace and url are expected to change 
      # after attempt to create project outside home
      @url = $data[:url] + "/project/new?ns=home%3A#{@user[:login]}"
      @namespace = "home:#{@user[:login]}:"
      
      permission_error  = "You lack the permission to create "
      permission_error += "the project '#{new_project[:namespace] + new_project[:name]}'. "
      permission_error += "Please create it in your home:#{current_user[:login]} namespace"
      validate { flash_message == permission_error }
      validate { flash_message_type == :alert }
      validate_page
    elsif new_project[:expect] == :already_exists
      validate { flash_message == message_prefix + "already exists." }
      validate { flash_message_type == :alert }
      validate_page
    else
      throw "Invalid value for argument <expect>."
    end
  end


end
