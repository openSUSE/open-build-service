# ==============================================================================
# Represents the page for interconnecting the build instance with e.g. build.o.o
#
class InterconnectPage < BuildServicePage
  
  # ============================================================================
  # (see WebPage#validate_page)
  #
  def validate_page
    super
    validate do
      @driver.page_source.include?("Connect a remote Open Build Service instance") or  
      @driver.page_source.include?("Add custom OBS instance")
    end
    assert_equal @url, $data[:url] + "/configuration/connect_instance"
  end
  
  
  # ============================================================================
  # (see WebPage#initialize)
  #
  def initialize web_driver, options={}
    super
    @user ||= $data[:user]
    @url = $data[:url] + "/configuration/connect_instance"
  end
  
  
  # ============================================================================
  # (see WebPage#initialize_ready)
  #
  def initialize_ready web_driver
    super
    @url = $data[:url] + "/configuration/connect_instance" 
  end
  
  
  def interconnect
    @driver[:xpath => "//input[@value='build.openSUSE.org']"].click
    
    name = @driver.find_element(:xpath => "//input[@name='name']")
    assert_equal name.attribute("value"), "openSUSE.org"

    @driver[:xpath => "//input[@name='commit']"].click
    assert_equal flash_message, "Project 'openSUSE.org' was created successfully. Next step is create your home project"
    assert_equal flash_message_type, :info

    $page = NewProjectPage.new_ready @driver
    $page.create_project(:title => "HomeProject Title",
                   :description => "Test generated empty home project for admin.")

  end


end
