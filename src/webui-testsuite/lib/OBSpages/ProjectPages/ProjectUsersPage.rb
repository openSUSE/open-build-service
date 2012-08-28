# ==============================================================================
# 
#
class ProjectUsersPage < ProjectPage


  # ============================================================================
  # (see WebPage#validate_page)
  #
  def validate_page
    super
    validate { @driver.page_source.include? "Users of " + @project }
    validate { @driver.page_source.include? "Add user" }
    validate { @driver.page_source.include? "Add group" }
  end


  # ============================================================================
  # (see WebPage#initialize)
  #
  def initialize web_driver, options={}
    super
    @url = $data[:url] + "/project/users?project=" + CGI.escape(@project)
  end
  

  # ============================================================================
  # (see WebPage#initialize_ready)
  #
  def initialize_ready web_driver
    super
    @url = @driver.current_url
    assert @url.start_with? $data[:url] + "/project/users?"
  end
  
  
  # ============================================================================
  #
  def add_user *args
    @driver[id: 'add-user'].click
    $page = ProjectAddUserPage.new_ready @driver
    $page.add_user *args
  end
  
  
  # ============================================================================
  #
  def add_group *args
    @driver[xpath: "//div[@id='content']//a[text()='Add group'"].click
    $page = ProjectAddGroupPage.new_ready @driver
    $page.add_group *args
  end
  
  
  # ============================================================================
  #
  def current_users
    rows = @driver.find_elements :css => "table#user_table tr"
    rows.delete_at(0)        # delete first 2 rows as
    rows.delete_at(0)        # they contain table headers
    results = []
    rows.each do |row|
      cell = row.find_elements :css => "td"
      puts row.text
      assert cell.count == 7
      name = cell[0].text
      name = name.split("(").last.split(")").first if name.include? "("
      results <<  { 
        :name       => name,
        :maintainer => cell[1].find_element(:css => "input").selected?,
        :bugowner   => cell[2].find_element(:css => "input").selected?,
        :reviewer   => cell[3].find_element(:css => "input").selected?,
        :downloader => cell[4].find_element(:css => "input").selected?,
        :reader     => cell[5].find_element(:css => "input").selected?  }
    end
    results
  end
  
  
  # ============================================================================
  #
  def edit_user options
    assert options[:name] != nil
    assert options[:name] != ""
    
    row = @driver[css: "table#user_table tr#user-#{valid_xml_id(options[:name].to_s)}"]
    cell = row.find_elements :css => "td"

    def edit_role cell, new_value 
      unless new_value.nil?
        unless cell.find_element(:css => "input").selected? == new_value
          cell.find_element(:css => "input").click
        end
      end
    end
    
    edit_role cell[1], options[:maintainer]
    edit_role cell[2], options[:bugowner]
    edit_role cell[3], options[:reviewer]
    edit_role cell[4], options[:downloader]
    edit_role cell[5], options[:reader]
    
    validate_page
  end
  
  
  # ============================================================================
  #
  def delete_user user
    href="/home?user=Admin"
    
    @driver[css: "table#user_table tr#user-#{valid_xml_id(options[:name].to_s)} a.remove-user"].click
    popup = @driver.switch_to.alert
    validate { popup.text == "Really remove '#{user}'?" }
    popup.accept
    validate_page
  end
  
  
end
