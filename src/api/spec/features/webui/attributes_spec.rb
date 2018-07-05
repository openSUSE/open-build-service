require 'browser_helper'

RSpec.feature 'Attributes', type: :feature, js: true do
  let!(:user) { create(:confirmed_user) }
  let!(:attribute_type) { create(:attrib_type) }

  def add_attribute_with_values(package = nil)
    visit index_attribs_path(project: user.home_project_name, package: package.try(:name))
    click_link('add-new-attribute')
    expect(page).to have_text('Add Attribute')
    find('select#attrib_attrib_type_id').select(attribute_type.name)
    click_button 'Create Attribute'
    expect(page).to have_content('Attribute was successfully created.')

    # Add two values
    click_link 'add value'
    click_link 'add value'

    fill_in 'Value', with: 'test 1', match: :first
    # Workaround to enter data into second textfield
    within('div.nested-fields:nth-of-type(2)') do
      fill_in 'Value', with: "test\n2nd line"
    end

    click_button 'Save Attribute'
  end

  describe 'for a project without packages' do
    scenario 'add attribute with values' do
      login user
      create(:attrib, project_id: user.home_project.id)

      add_attribute_with_values
      expect(page).to have_content('Attribute was successfully updated.')

      visit index_attribs_path(project: user.home_project_name)
      tr_tds = page.all('tr.attribute-values:nth-child(3) td').map(&:text)
      expect(tr_tds[0]).to eq("#{attribute_type.namespace}:#{attribute_type.name}")
      expect(tr_tds[1]).to eq("test\n2nd line\ntest 1")
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
        click_button('Create Attribute')
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
      login user

      add_attribute_with_values(package)
      expect(page).to have_content('Attribute was successfully updated.')

      visit index_attribs_path(project: user.home_project_name, package: package.name)
      tr_tds = page.all('tr.attribute-values:nth-child(2) td').map(&:text)
      expect(tr_tds[0]).to eq("#{attribute_type.namespace}:#{attribute_type.name}")
      expect(tr_tds[1]).to eq("test\n2nd line\ntest 1")
    end
  end
end
