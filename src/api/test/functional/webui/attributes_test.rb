require_relative '../../test_helper'

class Webui::AttributesTest < Webui::IntegrationTest
  ATTRIBUTES = %w(NSTEST:status OBS:VeryImportantProject OBS:UpdateProject
                  OBS:OwnerRootProject OBS:Maintained OBS:RequestCloned
                  OBS:InitializeDevelPackage OBS:MaintenanceProject OBS:MaintenanceIdTemplate
                  OBS:RejectRequests OBS:ApprovedRequestSource OBS:BranchTarget
                  OBS:ScreenShots OBS:ProjectStatusPackageFailComment OBS:QualityCategory).sort

  setup do
    use_js
  end

  def add(attribute) # spec/features/webui/attributes_spec.rb
    attribute[:value] ||= ''
    attribute[:expect] ||= :success
    attribute[:id] = attribute[:name].split(':').join('-')
    assert ATTRIBUTES.include?(attribute[:name]), "not included #{attribute[:name]}"

    # Create the attribute
    visit index_attribs_path(project: attribute[:project], package: attribute[:package] )
    click_link('add-new-attribute')
    page.must_have_text 'Add Attribute'

    find('select#attrib_attrib_type_id').select(attribute[:name])
    click_button 'Create Attribute'

    if attribute[:expect] == :success
      flash_message.must_equal 'Attribute was successfully created.'
      flash_message_type.must_equal :info
    elsif attribute[:expect] == :no_permission
      flash_message.must_equal "You have no permission to create attribute #{attribute[:name]}"
      flash_message_type.must_equal :alert
    end

    # Fill in values
    unless attribute[:value].blank?
      inputs = page.all('div.nested-fields')
      values = attribute[:value].split(',')
      # For the case that the AttribType has unlimited value_count
      # or that there are less values then
      # puts "BEFORE #{attribute[:name]}: VALUES: #{values.length} | INPUTS: #{inputs.count}"
      (values.length - inputs.count).times do
        click_link 'add value'
      end
      inputs = page.all('div.nested-fields')
      # puts "AFTER #{attribute[:name]}: VALUES: #{values.length} | INPUTS: #{inputs.count}"
      inputs.count.must_equal values.count

      values.each_index do |i|
        within("div.nested-fields:nth-of-type(#{i + 1})") do
          # If there is a position input we have multiple values
          if page.has_css?('.attrib-position-input')
            # If there is a select box for the value select that
            if page.has_css?('#attrib-default-select')
              page.select values[i], from: 'attrib-default-select'
            # If not fill the second input, the first (position) is irrelevant
            else
              find("input:nth-of-type(2)").set(values[i])
            end
          # If there is only a select box
          elsif page.has_css?('#attrib-default-select')
            page.select values[i], from: 'attrib-default-select'
          # If not just fill the first input
          else
            find("input:nth-of-type(1)").set(values[i])
          end
        end
      end

      click_button 'Save Attribute'
      if attribute[:expect] == :value_not_allowed
        flash_message.must_match %r{Saving attribute failed: attribute value #{attribute[:value]} for}
      end
    end

    unless attribute[:expect] == :no_permission
      # Check the existence and correct value
      visit index_attribs_path(project: attribute[:project], package: attribute[:package] )
      unless find(:css, "td.#{attribute[:id]}")
        raise "Did not find attribute \"#{attribute[:name]}\" after saving."
      end
    end

    return if attribute[:value].blank?

    values.each do |value|
      unless find(:css, "td.#{attribute[:id]}-values").has_text?(value)
        raise "Did not find value \"#{value}\" for \"#{attribute[:name]}\" after saving"
      end
    end
  end

  def delete(attribute) # spec/features/webui/attributes_spec.rb
    attribute[:value] ||= ''
    attribute[:expect] ||= :success
    attribute[:id] = attribute[:name].split(':').join('-')
    assert ATTRIBUTES.include? attribute[:name]
    visit index_attribs_path(project: attribute[:project], package: attribute[:package] )

    delete = find_button("#{attribute[:id]}-delete")
    unless delete
      raise "No such attribute #{attribute[:name]}"
    end

    # avoid the javascript popup
    page.evaluate_script('window.confirm = function() { return true; }')
    click_button("#{attribute[:id]}-delete")

    if attribute[:expect] == :success
      flash_message.must_equal 'Attribute sucessfully deleted!'
      flash_message_type.must_equal :info
    elsif attribute[:expect] == :no_permission
      flash_message.must_match %r{Deleting attribute failed: no permission to change attribute}
      flash_message_type.must_equal :alert
    end
  end

  def test_attrib_invalid_package # spec/features/webui/attributes_spec.rb
    visit index_attribs_path(project: 'home:Iggy', package: 'Pok')
    page.must_have_content "Package Pok not found"
  end

  def test_attrib_invalid_project # spec/features/webui/attributes_spec.rb
    visit index_attribs_path(project: 'Does:Not:Exist')
    page.must_have_content "Project not found: Does:Not:Exist"
  end

  def test_project_attribute # spec/features/webui/attributes_spec.rb
    login_king

    add(project: 'home:Iggy',
        name: 'OBS:ScreenShots',
        value: 'Screenshot1.png')
    delete(project: 'home:Iggy',
           name: 'OBS:ScreenShots')
  end

  def test_attrib_with_single_value
    login_king

    add(project: 'home:Iggy',
        name: 'OBS:ScreenShots',
        value: 'Screenshot1.png')
    delete(project: 'home:Iggy',
           name: 'OBS:ScreenShots')
  end

  def test_attrib_with_multiple_values # spec/features/webui/attributes_spec.rb
    login_king

    add(project: 'home:Iggy',
        name: 'OBS:ScreenShots',
        value: 'blah.jpg,blubb.jpg,blabber.jpg')
    delete(project: 'home:Iggy',
           name: 'OBS:ScreenShots')
  end

  def test_attrib_with_multiple_values_and_multiple_allowed_values
    login_king

    add(project: 'home:Iggy',
        name: 'OBS:OwnerRootProject',
        value: 'DisableDevel,BugownerOnly')
    delete(project: 'home:Iggy',
           name: 'OBS:OwnerRootProject')
  end

  def test_attrib_with_default_and_allowed_values
    login_Iggy

    add(project: 'home:Iggy',
        name: 'OBS:QualityCategory',
        value: 'Stable')
    delete(project: 'home:Iggy',
           name: 'OBS:QualityCategory')
  end
end
