# ==============================================================================
# Represents the greeter page at OBS.
#
class MainPage < BuildServicePage
  

  # ============================================================================
  # (see WebPage#validate_page)
  #
  def validate_page
    super
    validate { @driver.page_source.include? "Welcome to openSUSE Build Service" }
  end
  

  # ============================================================================
  # (see WebPage#initialize)
  #
  def initialize web_driver, options={}
    super
    @url = $data[:url]
  end
  

  # ============================================================================
  # (see WebPage#initialize_ready)
  #
  def initialize_ready web_driver
    super
    @url = $data[:url]
  end
  
  def open_status_monitor
    @driver[css: "div#content a[href='/monitor']"].click
    $page=StatusMonitorPage.new_ready @driver
  end
  
  def open_search
    @driver[css: "div#content a[href='/search']"].click
    $page=SearchPage.new_ready @driver
  end
  
  def open_all_projects
    @driver[css: "div#content a[href='/project/list_public']"].click
    $page=AllProjectsPage.new_ready @driver
  end
  
  def open_my_projects
    @driver[css: "div#content a[href='/home/list_my']"].click
    $page=MyProjectsPage.new_ready @driver
  end
  
  def open_new_project
    @driver[css: "#proceed-document-new a"].click
    $page=NewProjectPage.new_ready @driver
  end

  def add_new_message(message, severity)
    @driver[id: 'add-new-message'].click
    wait_for_javascript
    textarea = @driver[id: "message"]
    textarea.click
    textarea.send_keys message
    @driver[id: "severity"].find_elements(css: "option").each { |o| o.click if o.text == severity }
    @driver[css: "input[name='commit']"].click
    $page = MainPage.new_ready @driver
    validate { @driver.page_source.include? message }
  end

  def delete_message(text)
    thetr = nil
    @driver.find_elements(css: "table#messages tr").each do |tr|
      if tr.find_element(css: "td").text != text
        puts "different text '#{tr.find_element(css: "td").text}' '#{text}'"
        next
      end
      thetr = tr
    end
    assert !thetr.nil?
    thetr.find_element(css: ".delete-message").click
    wait_for_javascript
    @driver[id: "dialog_wrapper"].find_element(css: "input[name='commit']").click
    
    $page = MainPage.new_ready @driver
  end

end
