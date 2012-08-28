# ==============================================================================
# 
#
class SearchPage < BuildServicePage
    

  # ============================================================================
  # (see WebPage#validate_page)
  #
  def validate_page
    super
    validate { @driver.page_source.include?  "Search for Buildservice Projects or Packages" }
    validate { @driver.page_source.include? "Search term:" }
    validate { @driver.page_source.include? "Require attribute:" }
  end
  

  # ============================================================================
  # (see WebPage#initialize)
  #
  def initialize web_driver, options={}
    super
    @url = $data[:url] + "/search"
  end
  

  # ============================================================================
  # (see WebPage#initialize_ready)
  #
  def initialize_ready web_driver
    super
    @url = $data[:url] + "/search"
  end
  
  
  # ============================================================================
  #
  def search options
    options[:for]    ||= [:projects, :packages]
    options[:in]     ||= [:name]
    options[:expect] ||= :success
    
    text        = @driver[:id => "search_text"]
    project     = @driver[:id => 'project']
    package     = @driver[:id => 'package']
    name        = @driver[:id => 'name']
    title       = @driver[:id => 'title']
    description = @driver[:id => 'description']
    
    text.clear
    text.send_keys options[:text]
    project.click     if options[:for].include?(:projects) != project.selected?
    package.click     if options[:for].include?(:packages) != package.selected?
    name.click        if options[:in].include?(:name)      != name.selected?
    title.click       if options[:in].include?(:title)     != title.selected?
    description.click if options[:in].include?(:description) != description.selected?
    unless options[:attribute].nil?
      @driver.find_elements(css: "select#attribute option").each do |o|
	 o.click if o.text == options[:attribute] 
      end
    end
    @driver[:css => "#content form input[name=commit]"].click
    
    if options[:expect] == :success
      $page = SearchResultsPage.new_ready @driver
    elsif options[:expect] == :invalid_search_text
      validate {flash_message == 
        "Search String must contain at least 2 characters OR you search for an attribute." }
      validate { flash_message_type == :alert }
      validate_page
    elsif options[:expect] == :invalid_search_options
      #TODO: IMP
    end
  end
  
  
end
