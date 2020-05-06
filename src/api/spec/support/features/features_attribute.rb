module FeaturesAttribute
  def add_attribute_with_values(package = nil)
    visit index_attribs_path(project: user.home_project_name, package: package.try(:name))
    click_link('Add Attribute')
    expect(page).to have_text('Add Attribute')
    find('select#attrib_attrib_type_id').select("#{attribute_type.attrib_namespace}:#{attribute_type.name}", match: :first)
    click_button('Add')
    expect(page).to have_content('Attribute was successfully created.')

    # FIXME: With the cocoon gem, the first click is somehow not registered... but only when testing in Capybara
    click_link('Add a value')
    fill_in 'Value', with: 'test 1', match: :first

    click_link('Add a value')
    # Workaround to enter data into second textfield
    within('div.nested-fields:nth-of-type(2)') do
      fill_in 'Value', with: "test\n2nd line"
    end

    click_button('Save')
  end
end

RSpec.configure do |config|
  config.include FeaturesAttribute, type: :feature
end
