require 'browser_helper'

RSpec.describe 'Attributes', :js do
  let!(:user) { create(:confirmed_user, :with_home) }
  let(:attribute) { create(:attrib, project: user.home_project) }
  # AttribTypes are part of the seeds, so we can reuse them
  let!(:attribute_type) { AttribType.find_by(name: 'ImageTemplates') }

  describe 'for a project without packages' do
    it 'add attribute with values' do
      login user
      create(:attrib, project_id: user.home_project.id)

      add_attribute_with_values
      expect(page).to have_content('Attribute was successfully updated.')

      # check what is in the database as this is also returned by the API
      # browsers might sneak a \r in there
      attrib = user.home_project.find_attribute(attribute_type.namespace, attribute_type.name)
      expect(attrib.values.pluck(:value)).to eq(["test\n2nd line", 'test 1'])

      visit index_attribs_path(project: user.home_project_name)
      attribute_type_value = page.first('#attributes tr td', exact_text: attribute_type.fullname).sibling('td', match: :first).text
      expect(attribute_type_value).to eq("test\n2nd line\ntest 1")
    end

    describe 'with values that are not allowed' do
      xit 'add attribute should fail'
    end

    describe 'without permissions' do
      it 'add valid attribute with lack of permissions' do
        # Database cleaner deletes these tables. But we need them for the
        # permission to function.
        attrib_type = AttribType.where(name: 'VeryImportantProject').first
        attrib_type.attrib_type_modifiable_bies.create(role: Role.where(title: 'Admin').first)

        login user

        visit index_attribs_path(project: user.home_project_name)
        click_link('Add Attribute')
        find('select#attrib_attrib_type_id').select('OBS:VeryImportantProject')
        click_button('Add')
        expect(page).to have_content('Sorry, you are not authorized to create this attrib.')
      end
    end
  end

  context 'with an attribute' do
    before do
      # create attrib as user
      User.session = user
      attribute
      User.session = nil
    end

    context 'for a project' do
      context 'without permissions' do
        let!(:other_user) { create(:confirmed_user) }

        it 'is not possible to add an attribute, the link is not shown' do
          login other_user

          visit index_attribs_path(project: user.home_project_name)
          expect(page).to have_no_content('Add Attribute')
        end
      end

      context 'with permissions' do
        it 'remove attribute' do
          login user

          visit index_attribs_path(project: user.home_project_name)
          first('table tbody tr td').click if mobile?
          click_link 'Delete attribute'
          expect(find_by_id('delete-attribute-modal')).to have_text('Do you want to remove the attribute?')
          within('#delete-attribute-modal .modal-footer') do
            expect(page).to have_button('Remove')
            click_button('Remove')
          end
          expect(page).to have_css('#flash')
          within('#flash') do
            expect(page).to have_text('Attribute sucessfully deleted!')
          end
        end
      end
    end

    context 'for a project with a package' do
      let!(:package) do
        create(:package, project: user.home_project)
      end

      it 'add attribute with values' do
        login user

        add_attribute_with_values(package)
        expect(page).to have_content('Attribute was successfully updated.')

        visit index_attribs_path(project: user.home_project_name, package: package.name)
        attribute_type_value = page.first('#attributes tr td', exact_text: attribute_type.fullname).sibling('td', match: :first).text
        expect(attribute_type_value).to eq("test\n2nd line\ntest 1")
      end
    end
  end
end
