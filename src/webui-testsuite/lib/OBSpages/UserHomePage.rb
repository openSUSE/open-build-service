# ==============================================================================
# 
#
class UserHomePage < BuildServicePage
    

  # ============================================================================
  # (see WebPage#validate_page)
  #
  def validate_page
    super
    ps = @driver.page_source
    validate { ps.include? "Home of " + current_user[:login] }
    validate { ps.include? "User Info" }
    validate { ps.include? "Profile picture:" }
    validate { ps.include? "Real name:" }
    validate { ps.include? "Email address:" }
    validate { ps.include? "Related Links" }
  end
  

  # ============================================================================
  # (see WebPage#initialize)
  #
  def initialize web_driver, options={}
    super
    @url = $data[:url] + "/home"
  end
  

  # ============================================================================
  # (see WebPage#initialize_ready)
  #
  def initialize_ready web_driver
    super
    @url = $data[:url] + "/home"
  end

  
  # ============================================================================
  #
  def user_real_name
    @driver[:xpath => "//div[@id='content']//p[strong[text()='Real name:']]"].text[11..-1]
  end
  
  
  # ============================================================================
  #
  def change_user_real_name new_name
    @driver[:xpath => "//div[@id='content']//a[@href='/user/edit']"].click
    wait_for_javascript
    
    #validate { 
    #  @driver.page_source.include? "Editing User Data for User " + current_user[:login] }
    #validate { @driver.page_source.include? "Real name:" }
    
    @driver[:id => "realname"].clear
    @driver[:id => "realname"].send_keys new_name
    @driver[:xpath => "//form[@action='/user/save']
      //input[@name='commit'][@value='Save changes']"].click
    
    assert_equal flash_message,
        "User data for user '#{current_user[:login]}' successfully updated."
    assert_equal flash_message_type, :info
    validate_page
    
    new_name = "No real name set." if new_name == ""
    validate { user_real_name == new_name }
  end
  
  
end
