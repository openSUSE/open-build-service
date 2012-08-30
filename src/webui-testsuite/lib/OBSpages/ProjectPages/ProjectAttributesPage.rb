# ==============================================================================
# 
#
class ProjectAttributesPage < ProjectPage


  # ============================================================================
  # (see WebPage#validate_page)
  #
  def validate_page
    super
    validate { @driver.page_source.include? "Attributes of " + @project }
  end
  

  # ============================================================================
  # (see WebPage#initialize)
  #
  def initialize web_driver, options={}
    super
    @url = $data[:url] + "/project/attributes?project=" + CGI.escape(@project)
  end
  

  # ============================================================================
  # (see WebPage#initialize_ready)
  #
  def initialize_ready web_driver
    super
    @url = $data[:url] + "/project/attributes?project=" + CGI.escape(@project)
  end
  
  def project_attributes
    attributes_table = @driver[css: "div#content table"]
    rows = attributes_table.find_elements xpath: ".//tr"
    rows.delete_at 0    # removing first row as it contains the headers
    attributes = Hash.new
    rows.each do |row|
      attr  = row.find_element(xpath: ".//td[1]").text
      value = row.find_element(xpath: ".//td[2]").text
      value = "" if value == "no values set"
      attributes[attr] = value
    end
    attributes
  end
  
  def add_new_attribute attribute
    attribute[:value]  ||= ""
    attribute[:expect] ||= :success
    puts "not included #{attribute[:name]}" unless ATTRIBUTES.include? attribute[:name]
    assert ATTRIBUTES.include? attribute[:name]

    @driver[xpath: "//*[@id='content']//*[text()='Add a new attribute']"].click

    validate { @driver.page_source.include? 'Add New Attribute' }
    validate { @driver.page_source.include? 'Attribute name:' }
    validate { @driver.page_source.include? 'Values (e.g. "bar,foo,..."):' }
    
    options = @driver.find_elements css: "select#attribute option"
    options_array = options.collect { |opt| opt.text }
    puts options_array.inspect unless options_array.sort == ATTRIBUTES
    assert options_array.sort == ATTRIBUTES
    
    @driver[css: "select#attribute"].find_element(xpath: ".//*[text()='#{attribute[:name]}']").click
    @driver[:id => "values"].clear
    @driver[:id => "values"].send_keys attribute[:value]
    @driver[css: "div#content input[name='commit']"].click

    if attribute[:expect] == :success
      validate { flash_message == "Attribute sucessfully added!" }
      validate { flash_message_type == :info }
    elsif attribute[:expect] == :no_permission
      validate { flash_message ==
        "Saving attribute failed: user #{@user[:login]} has no permission to change attribute" }
      validate { flash_message_type == :alert }
    elsif attribute[:expect] == :value_not_allowed
      validate { flash_message.include?(
        "Saving attribute failed: attribute value #{attribute[:value]} for") }
    elsif attribute[:expect] == :wrong_number_of_values
      validate { flash_message.include? "Saving attribute failed: attribute " }
      validate { flash_message.include? "values, but" }
    end
    validate_page
  end

  def edit_attribute attribute
    attribute[:expect] ||= :success
    assert ATTRIBUTES.include? attribute[:name]
    
    attributes_table = @driver[css: "div#content table"]
    rows = attributes_table.find_elements xpath: ".//tr"
    rows.delete_at 0    # removing first row as it contains the headers
    results = rows.select do |row|
      row.find_element(xpath: ".//td[1]").text == attribute[:name]
    end
    assert results.count == 1
    
    results.first.find_element(xpath: ".//a[1]").click

    validate { @driver.page_source.include? "Edit Attribute #{attribute[:name]}" }
    validate { @driver.page_source.include? 'Values (e.g. "bar,foo,..."):' }
    
    @driver[:id => "values"].clear
    @driver[:id => "values"].send_keys attribute[:new_value]
    @driver[css: "div#content input[name='commit']"].click

    if attribute[:expect] == :success
      validate { flash_message == "Attribute sucessfully added!" }
      validate { flash_message_type == :info }
    elsif attribute[:expect] == :no_permission
      validate { flash_message ==
        "Saving attribute failed: user #{@user[:login]} has no permission to change attribute" }
      validate { flash_message_type == :alert }
    elsif attribute[:expect] == :value_not_allowed
      validate { flash_message.include?(
        "Saving attribute failed: attribute value #{attribute[:new_value]} for") }
      validate { flash_message_type == :alert }
    elsif attribute[:expect] == :wrong_number_of_values
      assert flash_message.include? "Saving attribute failed: attribute" 
      assert flash_message.include? "values, but" 
      assert_equal flash_message_type, :alert 
    end
    validate_page
  end

  def delete_attribute attribute
    attribute[:expect] ||= :success
    assert ATTRIBUTES.include? attribute[:name]
    
    attributes_table = @driver[css: "div#content table"]
    rows = attributes_table.find_elements css: "tr.attribute-values"
    results = rows.select do |row|
      row.find_element(css: "td.attribute-name").text == attribute[:name]
    end
    assert_equal results.count, 1
    results.first.find_element(css: "input.delete-attribute").click

    popup = @driver.switch_to.alert
    assert_equal popup.text, "Really remove attribute '#{attribute[:name]}'?"

    popup.accept
    wait.until { @driver.find_element(:id => "flash-messages") }

    if attribute[:expect] == :success
      assert_equal flash_message, "Attribute sucessfully deleted!"
      assert_equal flash_message_type, :info
    elsif attribute[:expect] == :no_permission
      assert_equal flash_message,
        "Deleting attribute failed: user #{@user[:login]} has no permission to change attribute"
      assert_equal flash_message_type, :alert 
    end
    validate_page
  end
  
end
