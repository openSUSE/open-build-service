# ==============================================================================
# 
#
class PackageSourcesPage < PackagePage


  # ============================================================================
  # (see WebPage#validate_page)
  #
  def validate_page
    super
    assert @url.start_with? $data[:url] + "/package/files"
  end
  

  # ============================================================================
  # (see WebPage#initialize)
  #
  def initialize web_driver, options={}
    super
    @url = $data[:url] + "/package/files"
    @url += "?package=#{@package}&project=#{CGI.escape(@project)}"
  end
  

  # ============================================================================
  # (see WebPage#initialize_ready)
  #
  def initialize_ready web_driver
    super
    @url = @driver.current_url
  end
  
  
  # ============================================================================
  #
  def open_add_file
    @driver[:xpath => 
      "//div[@id='content']//a[text()='Add file']"].click
    $page=PackageAddFilePage.new_ready @driver
  end
  
  
  # ============================================================================
  #
  def open_file file
    @driver[:xpath => ".//tr/td[1]/a[text()='#{file}']"].click
    $page = PackageEditFilePage.new_ready @driver
  end
  
end
