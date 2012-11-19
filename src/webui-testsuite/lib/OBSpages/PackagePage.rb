# ==============================================================================
# Represents a common page for all package related pages in OBS. Contains
# functionality like tabs and validations.
# @abstract
#
class PackagePage < ProjectPage
       
  
  # ============================================================================
  # (see WebPage#validate_page)
  #
  def validate_page
    super
    validate { @package == package }
    if @available_tabs.has_value? self.class then
      validate { @available_tabs[selected_tab] == self.class }
    else
      validate { selected_tab == :none }
    end
  end
    
  
  # ============================================================================
  # (see WebPage#initialize)
  #
  def initialize web_driver, options={}
    super
    @package = options[:package]
    @available_tabs = ALL_PACKAGE_TABS
    @advanced_tabs  = ADVANCED_PACKAGE_TABS
    @tabs_id = 'package_tabs'
    assert @package != nil
  end
    
  
  # ============================================================================
  # (see WebPage#initialize_ready)
  #
  def initialize_ready web_driver
    super
    @package = package
    @available_tabs = ALL_PACKAGE_TABS
    @advanced_tabs  = ADVANCED_PACKAGE_TABS
    @tabs_id = 'package_tabs'
  end
  

  ALL_PACKAGE_TABS = { "users"        => PackageUsersPage,
                       "overview"     => PackageOverviewPage,
                       "requests"     => PackageRequestsPage,
                       "meta"         => PackageRawConfigPage,
                       "revisions"    => PackageRevisionsPage,
                       "attributes"   => PackageAttributesPage,
                       "repositories" => PackageRepositoriesPage }
              
  ADVANCED_PACKAGE_TABS = [ "meta", "attributes" ]
  
  
  # ============================================================================
  #
  def package
    assert @driver.current_url.include? "package="
    CGI.unescapeHTML @driver.current_url.split("package=").last.split("&").first
  end

end
