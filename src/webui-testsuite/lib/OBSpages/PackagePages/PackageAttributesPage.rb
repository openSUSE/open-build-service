# ==============================================================================
# 
#
class PackageAttributesPage < PackagePage


  # ============================================================================
  # (see WebPage#validate_page)
  #
  def validate_page
    super
    assert @url.start_with? $data[:url] + "/package/attributes"
  end
  

  # ============================================================================
  # (see WebPage#initialize)
  #
  def initialize web_driver, options={}
    super
    @url = $data[:url] + "/package/attributes"
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
  def package_attributes
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
  
  
  # ============================================================================
  #
  def add_new_attribute attribute
    attribute[:value]  ||= ""
    attribute[:expect] ||= :success
    assert ATTRIBUTES.include? attribute[:name]

    @driver[ id: 'add-new-attribute'].click
    wait_for_page

    xpath_options = "//select[@id='attribute']/option"
    ps = @driver.page_source
    validate { ps.include? 'Add New Attribute' }
    validate { ps.include? 'Attribute name:' }
    validate { ps.include? 'Values (e.g. "bar,foo,..."):' }
    
    options = @driver.find_elements css: "select#attribute option"
    options_array = options.collect { |opt| opt.text }
    assert_equal options_array.sort, ATTRIBUTES
    
    options.each { |o| o.click if o.text == attribute[:name] }
    @driver[:id => "values"].clear
    @driver[:id => "values"].send_keys attribute[:value]
    @driver[css: "div#content input[name='commit']"].click

    if attribute[:expect] == :success
      assert_equal flash_message, "Attribute sucessfully added!" 
      assert_equal flash_message_type, :info 
    elsif attribute[:expect] == :no_permission
      assert_equal flash_message,
        "Saving attribute failed: user #{@user[:login]} has no permission to change attribute"
      assert_equal flash_message_type, :alert 
    elsif attribute[:expect] == :value_not_allowed
      validate { flash_message.include?(
        "Saving attribute failed: attribute value #{attribute[:value]} for") }
    elsif attribute[:expect] == :wrong_number_of_values
      validate { flash_message.include? "Saving attribute failed: attribute '#{attribute[:name]}' requires" }
      validate { flash_message.include? "values, but" }
    elsif attribute[:expect] == :too_many_values
      validate { flash_message.include? "Saving attribute failed: attribute '#{attribute[:name]}' has" }
      validate { flash_message.include? "values, but" }
    end
    validate_page
  end

  
  # ============================================================================
  #
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
      validate { flash_message.include? "Saving attribute failed: attribute" }
      validate { flash_message.include? "values, but" }
      validate { flash_message_type == :alert }
    end
    validate_page
  end

  
  # ============================================================================
  #
  def delete_attribute attribute
    attribute[:expect] ||= :success
    assert ATTRIBUTES.include? attribute[:name]
    
    attributes_table = @driver[css: "div#content table"]
    rows = attributes_table.find_elements xpath: ".//tr"
    rows.delete_at 0    # removing first row as it contains the headers
    results = rows.select do |row|
      row.find_element(xpath: ".//td[1]").text == attribute[:name]
    end
    assert results.count == 1
    results.first.find_element(xpath: ".//a[2]/img").click

    popup = @driver.switch_to.alert
    validate { popup.text == "Really remove attribute '#{attribute[:name]}'?" }

    popup.accept
    wait_for_javascript
    wait_for_page

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
