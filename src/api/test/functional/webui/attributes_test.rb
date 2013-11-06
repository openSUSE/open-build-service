require 'test_helper'

class Webui::AddAttributesTest < Webui::IntegrationTest

  ATTRIBUTES = ['NSTEST:status',
                'OBS:VeryImportantProject',
                'OBS:UpdateProject',
                'OBS:OwnerRootProject',
                'OBS:Maintained',
                'OBS:RequestCloned',
                'OBS:InitializeDevelPackage',
                'OBS:MaintenanceProject',
                'OBS:MaintenanceIdTemplate',
                'OBS:RejectRequests',
                'OBS:ApprovedRequestSource',
                'OBS:BranchTarget',
                'OBS:ScreenShots',
                'OBS:ProjectStatusPackageFailComment',
                'OBS:QualityCategory'].sort

  def edit_attribute attribute
    attribute[:expect] ||= :success
    assert ATTRIBUTES.include? attribute[:name]

    attributes_table = @driver[css: 'div#content table']
    rows = attributes_table.find_elements xpath: './/tr'
    rows.delete_at 0 # removing first row as it contains the headers
    results = rows.select do |row|
      row.find_element(xpath: './/td[1]').text == attribute[:name]
    end
    results.count.must_equal 1

    results.first.find_element(xpath: './/a[1]').click

    validate { @driver.page_source.include? "Edit Attribute #{attribute[:name]}" }
    validate { @driver.page_source.include? 'Values (e.g. "bar,foo,..."):' }

    @driver[:id => 'values'].clear
    @driver[:id => 'values'].send_keys attribute[:new_value]
    @driver[css: "div#content input[name='commit']"].click

    if attribute[:expect] == :success
      flash_message.must_equal 'Attribute sucessfully added!'
      flash_message_type.must_equal :info
    elsif attribute[:expect] == :no_permission
      flash_message.must_equal "Saving attribute failed: user #{@user[:login]} has no permission to change attribute"
      flash_message_type.must_equal :alert
    elsif attribute[:expect] == :value_not_allowed
      validate { flash_message.include?(
          "Saving attribute failed: attribute value #{attribute[:new_value]} for") }
      validate { flash_message_type == :alert }
    elsif attribute[:expect] == :wrong_number_of_values
      assert flash_message.include? 'Saving attribute failed: attribute'
      assert flash_message.include? 'values, but'
      flash_message_type.must_equal :alert
    end
    validate_page
  end

  def add_new_attribute attribute
    attribute[:value] ||= ''
    attribute[:expect] ||= :success
    assert ATTRIBUTES.include?(attribute[:name]), "not included #{attribute[:name]}"

    click_link('Add a new attribute')

    page.must_have_text 'Add New Attribute'
    page.must_have_text 'Attribute name:'
    page.must_have_text 'Values (e.g. "bar,foo,..."):'

    find('select#attribute').select(attribute[:name])
    fill_in 'values', with: attribute[:value]
    click_button 'Save attribute'

    if attribute[:expect] == :success
      flash_message.must_equal 'Attribute sucessfully added!'
      flash_message_type.must_equal :info
    elsif attribute[:expect] == :no_permission
      flash_message.must_equal 'No permission to save attribute'
      flash_message_type.must_equal :alert
    elsif attribute[:expect] == :value_not_allowed
      flash_message.must_match %r{Saving attribute failed: attribute value #{attribute[:value]} for}
    elsif attribute[:expect] == :wrong_number_of_values
      flash_message.must_match %r{Saving attribute failed: attribute.*values, but}
    end
  end

  def delete_attribute attribute
    attribute[:expect] ||= :success
    assert ATTRIBUTES.include? attribute[:name]

    results = all('tr.attribute-values').select do |row|
      row.find(:css, 'td.attribute-name').text == attribute[:name]
    end
    if results.empty?
      raise "No such attribute #{attribute[:name]}"
    end

    # avoid the javascript popup
    page.evaluate_script('window.confirm = function() { return true; }')
    results.first.find(:css, 'input.delete-attribute').click

    if attribute[:expect] == :success
      flash_message.must_equal 'Attribute sucessfully deleted!'
      flash_message_type.must_equal :info
    elsif attribute[:expect] == :no_permission
      flash_message.must_match %r{Deleting attribute failed: no permission to change attribute}
      flash_message_type.must_equal :alert
    end
  end

  test 'add_all_permited_project_attributes_for_user' do
    login_Iggy
    visit webui_engine.project_attributes_path(project: 'home:Iggy')

    add_new_attribute(name: 'OBS:RequestCloned',
                      value: 'cloneclone')
    add_new_attribute(name: 'OBS:ProjectStatusPackageFailComment',
                      value: 'some_value_comment')
    add_new_attribute(name: 'OBS:InitializeDevelPackage')
    add_new_attribute(name: 'OBS:QualityCategory',
                      value: 'Stable')

    logout
    # admin should be able to delete all
    login_king
    visit webui_engine.project_attributes_path(project: 'home:Iggy')
    delete_attribute name: 'OBS:RequestCloned'
    delete_attribute name: 'OBS:ProjectStatusPackageFailComment'
    delete_attribute name: 'OBS:InitializeDevelPackage'

  end


  test 'add_all_permited_project_attributes_for_second_user' do

    login_tom
    visit webui_engine.project_attributes_path(project: 'home:tom')
    add_new_attribute(name: 'OBS:RequestCloned',
                      value: 'cloneclone')
    add_new_attribute(name: 'OBS:ProjectStatusPackageFailComment',
                      value: 'some_value_comment')
    add_new_attribute(name: 'OBS:InitializeDevelPackage')
    add_new_attribute(name: 'OBS:QualityCategory',
                      value: 'Stable')
  end


  test 'add_all_not_permited_project_attributes_for_user' do
    login_Iggy
    visit webui_engine.project_attributes_path(project: 'home:Iggy')
    add_new_attribute(name: 'OBS:VeryImportantProject',
                      value: '',
                      expect: :no_permission)
  end


  test 'add_invalid_value_for_project_attribute' do
    login_Iggy
    visit webui_engine.project_attributes_path(project: 'home:Iggy')
    add_new_attribute(name: 'OBS:QualityCategory',
                      value: 'invalid_value',
                      expect: :value_not_allowed)
  end


  test 'wrong_number_of_values_for_project_attribute' do

    login_Iggy
    visit webui_engine.project_attributes_path(project: 'home:Iggy')
    add_new_attribute(name: 'OBS:ProjectStatusPackageFailComment',
                      value: 'val1,val2,val3',
                      expect: :wrong_number_of_values)
  end


  test 'add_same_project_attribute_twice' do

    login_Iggy
    visit webui_engine.project_attributes_path(project: 'home:Iggy')
    add_new_attribute(name: 'OBS:RequestCloned',
                      value: 'value1')
    add_new_attribute(name: 'OBS:RequestCloned',
                      value: 'value2')
  end


  test 'add_all_admin_permited_project_attributes' do

    login_king
    visit webui_engine.project_attributes_path(project: 'home:Iggy')

    add_new_attribute(name: 'OBS:VeryImportantProject')
    add_new_attribute(name: 'OBS:OwnerRootProject',
                      value: 'BugownerOnly')
    add_new_attribute(name: 'OBS:UpdateProject',
                      value: 'now')
    add_new_attribute(name: 'OBS:RejectRequests',
                      value: 'yes')
    add_new_attribute(name: 'OBS:ApprovedRequestSource')
    add_new_attribute(name: 'OBS:Maintained')
    add_new_attribute(name: 'OBS:MaintenanceProject',
                      value: '')
    add_new_attribute(name: 'OBS:MaintenanceIdTemplate',
                      value: 'dontbesilly')
    add_new_attribute(name: 'OBS:ScreenShots',
                      value: 'scarystuff')
    add_new_attribute(name: 'OBS:RequestCloned',
                      value: 'cloneclone')
    add_new_attribute(name: 'OBS:ProjectStatusPackageFailComment',
                      value: 'some_value_comment')
    add_new_attribute(name: 'OBS:InitializeDevelPackage')

    # and can it be deleted again?
    delete_attribute name: 'OBS:VeryImportantProject'
    delete_attribute name: 'OBS:UpdateProject'
    delete_attribute name: 'OBS:RejectRequests'
    delete_attribute name: 'OBS:ApprovedRequestSource'
    delete_attribute name: 'OBS:Maintained'
    delete_attribute name: 'OBS:MaintenanceProject'
    delete_attribute name: 'OBS:MaintenanceIdTemplate'
    delete_attribute name: 'OBS:ScreenShots'
    delete_attribute name: 'OBS:RequestCloned'
    delete_attribute name: 'OBS:ProjectStatusPackageFailComment'
    delete_attribute name: 'OBS:InitializeDevelPackage'

  end


  test 'add_all_permited_package_attributes_for_user' do
    login_Iggy
    visit webui_engine.package_attributes_path(project: 'home:Iggy', package: 'TestPack')
    add_new_attribute(name: 'OBS:RequestCloned',
                      value: 'cloneclone')
    add_new_attribute(name: 'OBS:ProjectStatusPackageFailComment',
                      value: 'some_value_comment')
    add_new_attribute(name: 'OBS:InitializeDevelPackage')
    # TODO: Add QualityCategory as it's obviously permited
    #       but still can't guess any acceptable values
  end


  test 'add_all_permited_package_attributes_for_second_user' do
    login_tom
    visit webui_engine.package_attributes_path(project: 'home:coolo:test', package: 'kdelibs_DEVEL_package')

    add_new_attribute(name: 'OBS:RequestCloned',
                      value: 'cloneclone')
    add_new_attribute(name: 'OBS:ProjectStatusPackageFailComment',
                      value: 'some_value_comment')
    add_new_attribute(name: 'OBS:InitializeDevelPackage')
    # TODO: Add QualityCategory as it's obviously permited
    #       but still can't guess any acceptable values
  end


  test 'add_all_not_permited_package_attributes_for_user' do

    login_Iggy
    visit webui_engine.package_attributes_path(project: 'home:Iggy', package: 'TestPack')
    add_new_attribute(name: 'OBS:ApprovedRequestSource',
                      value: '',
                      expect: :success)
    add_new_attribute(name: 'OBS:VeryImportantProject',
                      value: '',
                      expect: :no_permission)
    visit webui_engine.package_attributes_path(project: 'home:Iggy', package: 'TestPack')
    add_new_attribute(name: 'OBS:UpdateProject',
                      value: '',
                      expect: :no_permission)
    visit webui_engine.package_attributes_path(project: 'home:Iggy', package: 'TestPack')
    add_new_attribute(name: 'OBS:Maintained',
                      value: '',
                      expect: :success)
    add_new_attribute(name: 'OBS:MaintenanceProject',
                      value: '',
                      expect: :no_permissions)
    visit webui_engine.package_attributes_path(project: 'home:Iggy', package: 'TestPack')
    add_new_attribute(name: 'OBS:MaintenanceIdTemplate',
                      value: '',
                      expect: :no_permission)
    visit webui_engine.package_attributes_path(project: 'home:Iggy', package: 'TestPack')
    add_new_attribute(name: 'OBS:ScreenShots',
                      value: '',
                      expect: :no_permission)
  end


  test 'add_invalid_value_for_package_attribute' do

    login_Iggy
    visit webui_engine.package_attributes_path(project: 'home:Iggy', package: 'TestPack')
    add_new_attribute(name: 'OBS:QualityCategory',
                      value: 'invalid_value',
                      expect: :value_not_allowed)
  end


  test 'wrong_number_of_values_for_package_attribute' do

    login_Iggy
    visit webui_engine.package_attributes_path(project: 'home:Iggy', package: 'TestPack')
    add_new_attribute(name: 'OBS:ProjectStatusPackageFailComment',
                      value: 'val1,val2,val3',
                      expect: :too_many_values)
  end


  test 'add_same_package_attribute_twice' do

    login_Iggy
    visit webui_engine.package_attributes_path(project: 'home:Iggy', package: 'TestPack')
    add_new_attribute(name: 'OBS:RequestCloned',
                      value: 'value1')
    add_new_attribute(name: 'OBS:RequestCloned',
                      value: 'value2')
  end


  test 'add_all_admin_permited_package_attributes' do

    login_king
    visit webui_engine.package_attributes_path(project: 'home:Iggy', package: 'TestPack')

    add_new_attribute(name: 'OBS:VeryImportantProject')
    add_new_attribute(name: 'OBS:UpdateProject',
                      value: 'now')
    add_new_attribute(name: 'OBS:RejectRequests',
                      value: 'yes')
    add_new_attribute(name: 'OBS:ApprovedRequestSource')
    add_new_attribute(name: 'OBS:Maintained')
    add_new_attribute(name: 'OBS:MaintenanceProject',
                      value: '')
    add_new_attribute(name: 'OBS:MaintenanceIdTemplate',
                      value: 'dontbesilly')
    add_new_attribute(name: 'OBS:ScreenShots',
                      value: 'scarystuff')
    add_new_attribute(name: 'OBS:RequestCloned',
                      value: 'cloneclone')
    add_new_attribute(name: 'OBS:ProjectStatusPackageFailComment',
                      value: 'some_value_comment')
    add_new_attribute(name: 'OBS:InitializeDevelPackage')

    logout
    login_Iggy
    visit webui_engine.package_attributes_path(project: 'home:Iggy', package: 'TestPack')

    delete_attribute(name: 'OBS:VeryImportantProject',
                     expect: :no_permission)
    delete_attribute(name: 'OBS:UpdateProject',
                     expect: :no_permission)
    delete_attribute name: 'OBS:RejectRequests'
    delete_attribute name: 'OBS:ApprovedRequestSource'
    delete_attribute name: 'OBS:Maintained'
    delete_attribute name: 'OBS:MaintenanceProject', expect: :no_permission
    delete_attribute name: 'OBS:MaintenanceIdTemplate', expect: :no_permission
    delete_attribute name: 'OBS:ScreenShots', expect: :no_permission
    delete_attribute name: 'OBS:RequestCloned'
    delete_attribute name: 'OBS:ProjectStatusPackageFailComment'
    delete_attribute name: 'OBS:InitializeDevelPackage'

  end

  test 'delete_user_created_project_attributes' do

    # add attributes as Iggy
    login_Iggy
    visit webui_engine.project_attributes_path(project: 'home:Iggy')

    add_new_attribute(name: 'OBS:RequestCloned',
                      value: 'cloneclone')
    add_new_attribute(name: 'OBS:ProjectStatusPackageFailComment',
                      value: 'some_value_comment')
    add_new_attribute(name: 'OBS:InitializeDevelPackage')

    # try to delete as tom - fails
    logout
    login_tom
    visit webui_engine.project_attributes_path(project: 'home:Iggy')

    delete_attribute(name: 'OBS:RequestCloned', expect: :no_permission)
    delete_attribute(name: 'OBS:ProjectStatusPackageFailComment', expect: :no_permission)
    delete_attribute(name: 'OBS:InitializeDevelPackage', expect: :no_permission)

    # test to delete as Iggy
    logout
    login_Iggy
    visit webui_engine.project_attributes_path(project: 'home:Iggy')

    delete_attribute name: 'OBS:RequestCloned'
    delete_attribute name: 'OBS:ProjectStatusPackageFailComment'
    delete_attribute name: 'OBS:InitializeDevelPackage'

  end

end
