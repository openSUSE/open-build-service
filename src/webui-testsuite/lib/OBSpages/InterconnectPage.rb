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
    @driver[:value => "build.openSUSE.org"].click
    
    name = @driver.find_element("input[@name='name']") 
    assert_equal name.value, "openSUSE.org"

    page.commit
  end


end
