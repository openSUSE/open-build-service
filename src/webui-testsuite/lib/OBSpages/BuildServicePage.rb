# ==============================================================================
# BuildServicePage is an abstract class that represents all common functionality
# of Open Build Service pages like header, footer, breadcrumb etc.
# @abstract
#

require 'erb'

class BuildServicePage < WebPage  

  # ============================================================================
  # (see WebPage#validate_page)
  #

  # ============================================================================
  # (see WebPage#validate_page)
  #
  def validate_page
    super
    res = wait_for_page
    assert res
    assert_equal res.shift["id"], "header-logo"
    assert_equal current_user, @user
    assert_equal @driver.current_url, @url
  end
  
  def _userstring(user) 
	  if user == :none
		  "none"
	  else
		  user[:login]
	  end
  end

  # ============================================================================
  # (see WebPage#initialize)
  #
  def initialize web_driver, options={}
    super
    #puts "\n  #{self.class}.initialize #{_userstring(options[:user])}"
    @user = options[:user]
  end
  
  
  # ============================================================================
  # (see WebPage#initialize_ready)
  #
  def initialize_ready web_driver
    super
    #puts "\n  #{self.class}.initialize_ready #{_userstring(current_user)}"
    @user = current_user
  end
  

  # ============================================================================
  # Restores the browser to the correct page. Assumes that the object has
  # been initialized properly and all needed page variables are defined.
  # @note In case that the expected user isn't strictly specified 
  #   this method assigns @user to the currently logged user.
  #
  def restore
    super
    if @driver.current_url != @url
      @driver.get @url
    end
    wait_for_page
    if @user.nil?
      @user = current_user
    else
      verify_login @user
    end
  end
  
  
  # ============================================================================
  # Logs in with the given username and password.
  # @param [Hash] user the user credentials to be used for the login,
  #   must be a hash of with the following keys:  
  #   { :login=>String , :password=>String }
  # @param [:success, :error] expect the expected result from the action
  #
  def login_as user, expect = :success
    assert([:success,:error,:admin].include? expect)
    validate { !user_is_logged? }

    @driver[id: "login-trigger"].click
    @driver[id: "username"].clear
    @driver[id: "username"].send_keys user[:login]
    @driver[id: "password"].clear
    @driver[id: "password"].send_keys user[:password]
    @driver[css: "div#login-form input[name=commit]"].click

    if expect == :admin || expect == :success
      #puts "\n  login_as @user = #{_userstring(user)}"
      @user = user
      
      validate { user_is_logged? }
      if expect == :admin && is_interconnect_page?
	 $page = InterconnectPage.new_ready @driver
	 return :interconnect
      end
      assert_equal flash_message, "You are logged in now"
      assert_equal flash_message_type, :info
      validate_page
      return :success
    else
      assert_equal flash_message, "Authentication failed"
      assert_equal flash_message_type, :alert 
      
      #puts "\n  login failed - user none"
      @user = :none
      $page = LoginPage.new_ready @driver
    end
  end
  
  # checks if the admin ended on the interconnect setup page
  def is_interconnect_page?
    x = @driver.find_element css: "div#content > div > h2"
    return x.text == "Connect a remote Open Build Service instance"
  end
  
  # ============================================================================
  # logs in the user unless he's already in. Useful for tests to make sure the 
  # correct user is logged in - :depends on works if it's working one by one in line
  def verify_login user
    cu = current_user
    if cu != user
      unless cu == :none
        logout
        if @driver.current_url != @url
          @driver.get @url
	  wait_for_page
        end
      end
      if user != :none
        login_as user
	wait_for_page
      end
      if @driver.current_url != @url
         @driver.get @url
	 wait_for_page
      end
    end
  end

  # ============================================================================
  # Logs out the current user. In case of MainPage updates
  # current object and validates state of the displayed page.
  # @note In any other case spawns new MainPage without logged user.
  #
  def logout
    @driver[css: "div#subheader a[href='/user/logout']"].click
    validate { not user_is_logged? }
    
    #puts "\n  logout user = none"
    @user = :none
    if self.class == MainPage then
      validate_page
    else
      $page = MainPage.new_ready @driver
    end
  end
  
  # verifies the correct user is logged in
  def navigate_to page, options={}
     if options[:user]
       verify_login options[:user]
     end
     super
  end

  
  # ============================================================================
  # Checks if the user has new requests
  #
  def user_has_new_requests?
    results = @driver.find_elements css: "div#subheader a[href='/home/my_work']"
    not results.empty?
  end
  
  
  # ============================================================================
  # Checks if a flash message is displayed on screen
  #
  def flash_message_appeared?
    flash_message_type != nil
  end


  # ============================================================================
  # Returns the text of the flash message currenlty on screen
  # @note Doesn't fail if no message is on screen. Returns empty string instead.
  # @return [String]
  #
  def flash_message
    results = @driver.find_elements css: "div#flash-messages p"
    if results.empty?
      return "none"
    end
    raise "One flash expected, but we had more." if results.count != 1
    return results.first.text
  end
  
  # ============================================================================
  # Returns the text of the flash messages currenlty on screen
  # @note Doesn't fail if no message is on screen. Returns empty list instead.
  # @return [array]
  #
  def flash_messages
    results = @driver.find_elements css: "div#flash-messages p"
    ret = []
    results.each { |r| ret << r.text }
    return ret
  end
 
  # ============================================================================
  # Returns the type of the flash message currenlty on screen
  # @note Does not fail if no message is on screen! Returns nil instead!
  # @return [:info, :alert]
  #
  def flash_message_type
    results = @driver.find_elements css: "div#flash-messages span"
    return nil if results.empty?
    return :info  if results.first.attribute("class").include? "info"
    return :alert if results.first.attribute("class").include? "alert" 
  end
  
  
  # ============================================================================
  # Gets the currently logged user.
  # @note The method expects that the current user exist as an entry in $data.
  # @return [Hash, :none] the credentials of the current user or :none.
  #
  def current_user
    unless user_is_logged?
      return :none
    end
    username = @driver[css: "div#subheader a[href='/home']"].text
    matched_users = Array.new
    $data.each_value do |user|
      if Hash === user and user[:login] == username
         matched_users << user
      end
    end
    assert matched_users.size == 1
    matched_users.first
  end
  
  
  # ============================================================================
  # Checks if a user is logged
  #
  def user_is_logged?
    x = nil
    wait.until {
      x = @driver.find_elements(id: 'subheader')
      !x.empty?
    }
    return x && x.first && !x.first.find_elements(css: "a#logout-link").empty?
  end
  
  
  # ============================================================================
  # Opens user's home profile from the link in the header.
  #
  def open_home
    @driver[css: "div#subheader a[href='/home']"].click
    $page = UserHomePage.new_ready @driver
  end
  
  
  # ============================================================================
  # Opens the Status Monitor page from the link in the footer.
  #
  def open_status_monitor
    @driver[css: "div#footer a[href='/monitor']"].click
    $page=StatusMonitorPage.new_ready @driver
  end
  
  
  # ============================================================================
  # Opens the Search page from the link in the footer.
  #
  def open_search
    @driver[css: "div#footer a[href='/search']"].click
    $page=SearchPage.new_ready @driver
  end
  
  
  # ============================================================================
  # Opens All Projects page from the link in the footer.
  #
  def open_all_projects
    @driver[css: "div#footer a[href='/project/list_public']"].click
    $page=AllProjectsPage.new_ready @driver
  end
  
  
  # ============================================================================
  # Opens user's projects page from the link in the footer.
  #
  def open_my_projects
    @driver[css: "div#footer a[href='/home/list_my']"].click
    $page=MyProjectsPage.new_ready @driver
  end
  
  
  # ============================================================================
  # Opens user's work page from the link in the footer.
  #
  def open_my_work
    @driver[css: "div#footer a[href='/home/my_work']"].click
    $page = MyWorkPage.new_ready @driver
  end

  def page_source
    @driver.page_source
  end

  def wait_for_javascript
    wait.until {
      @driver.execute_script('return jQuery.active') == 0
    }
  end

  def wait_for_page
    res = nil
    wait.until {
      res = @driver.find_elements(id: 'header-logo')
      !res.empty?
    }
    res
  end

  def valid_xml_id(rawid)
    rawid = '_' + rawid if rawid !~ /^[A-Za-z_]/ # xs:ID elements have to start with character or '_'
    ERB::Util::h(rawid.gsub(/[+&: .\/\~\(\)@]/, '_'))
  end
end
