require 'browser_helper'

RSpec.feature 'Attributes', type: :feature, js: true do
  let!(:user) { create(:confirmed_user) }
  # AttribTypes are part of the seeds, so we can reuse them
  let!(:attribute_type) { AttribType.find_by(name: 'ImageTemplates') }

  def add_attribute_with_values(package = nil)
    visit index_attribs_path(project: user.home_project_name, package: package.try(:name))
    click_link('Add a new attribute')
    expect(page).to have_text('Add Attribute')
    find('select#attrib_attrib_type_id').select(attribute_type.name)
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

  describe 'for a project without packages' do
    scenario 'add attribute with values' do
      login user
      create(:attrib, project_id: user.home_project.id)

      add_attribute_with_values
      expect(page).to have_content('Attribute was successfully updated.')

      # check what is in the database as this is also returned by the API
      # browsers might sneak a \r in there
      attrib = user.home_project.find_attribute(attribute_type.namespace, attribute_type.name)
      expect(attrib.values.pluck(:value)).to eq(["test\n2nd line", 'test 1'])

      visit index_attribs_path(project: user.home_project_name)
      attribute_type_value = page.all('#attributes tr td', exact_text: attribute_type.fullname)[0].sibling('td', match: :first).text
      expect(attribute_type_value).to eq("test\n2nd line\ntest 1")
    end

    describe 'with values that are not allowed' do
      scenario 'add attribute should fail' do
        skip
      end
    end

    describe 'without permissions' do
      let!(:other_user) { create(:confirmed_user) }

      scenario 'add attribute with values should fail' do
        login other_user

        visit index_attribs_path(project: user.home_project_name)
        click_link('add-new-attribute')
        expect(page).to have_content('Sorry, you are not authorized to create this Attrib.')
      end

      scenario 'add valid attribute with lack of permissions' do
        # Database cleaner deletes these tables. But we need them for the
        # permission to function.
        attrib_type = AttribType.where(name: 'VeryImportantProject').first
        attrib_type.attrib_type_modifiable_bies.create(role: Role.where(title: 'Admin').first)

        login user

        visit index_attribs_path(project: user.home_project_name)
        click_link('Add a new attribute')
        find('select#attrib_attrib_type_id').select('OBS:VeryImportantProject')
        click_button('Add')
        expect(page).to have_content('Sorry, you are not authorized to create this Attrib.')
      end
    end

    scenario 'remove attribute' do
      login user
      attribute = create(:attrib, project_id: user.home_project.id)

      visit index_attribs_path(project: user.home_project_name)

      accept_alert do
        find("##{attribute.namespace}-#{attribute.name}-delete").click
      end
      expect(page).to have_content('Attribute sucessfully deleted!')
    end
  end

  describe 'for a project with a package' do
    let!(:package) do
      create(:package, project_id: user.home_project.id)
    end

    scenario 'add attribute with values' do
      skip_if_bootstrap

      login user

      add_attribute_with_values(package)
      expect(page).to have_content('Attribute was successfully updated.')

      visit index_attribs_path(project: user.home_project_name, package: package.name)
      attribute_type_value = page.all('#attributes tr td', exact_text: attribute_type.fullname)[0].sibling('td', match: :first).text
      expect(attribute_type_value).to eq("test\n2nd line\ntest 1")
    end
  end
end
