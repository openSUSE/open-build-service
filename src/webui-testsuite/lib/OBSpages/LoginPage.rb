# ==============================================================================
# Represents the Login Page at OBS that gets displayed upon
# unsuccessful login attempt (/user/login)
#
class LoginPage < BuildServicePage
  

  # ============================================================================
  # (see WebPage#validate_page)
  #
  def validate_page
    super
    validate { @driver.page_source.include? "Please Login" }
    validate { @driver.page_source.include? "Username:" }
    validate { @driver.page_source.include? "Password:" }
  end
  

  # ============================================================================
  # (see WebPage#initialize)
  #
  def initialize web_driver, options={}
    super
    @url = $data[:url] + "/user/login"
  end
  

  # ============================================================================
  # (see WebPage#initialize_ready)
  #
  def initialize_ready web_driver
    super
    @url = @driver.current_url
    assert(
      (@url.start_with? $data[:url] + "/user/login") ||
      (@url.start_with? $data[:url] + "/user/do_login") )
  end
  

  # ============================================================================
  # Logs in with the given username and password.
  # @note Uses the static fields in the middle of the page to 
  #   login instead of the AJAX dropdown menu in the header
  # @param [Hash] user the user credentials to be used for the login,
  #   must be a hash of with the following keys:  
  #   { :login=>String , :password=>String }
  # @param [:success, :error] expect the expected result from the action
  #
  def login_as user, expect = :success
    validate { [:success,:error].include? expect }
    validate { not user_is_logged? }

    @driver[:id => "user_login"].clear
    @driver[:id => "user_login"].send_keys user[:login]
    @driver[:id => "user_password"].clear
    @driver[:id => "user_password"].send_keys user[:password]
    @driver[:xpath => "//div[@id='loginform']//input[@name='login']"].click

    if expect == :success
      assert_equal flash_message, "You are logged in now"
      assert_equal flash_message_type, :info
      $page = MainPage.new_ready @driver
    else expect == :error
      validate { flash_message == "Authentication failed" }
      validate { flash_message_type == :alert }
      validate_page
    end

  end


end
