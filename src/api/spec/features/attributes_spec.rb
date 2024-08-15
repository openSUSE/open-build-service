require 'browser_helper'

RSpec.feature 'Bootstrap_Attributes', type: :feature, js: true do
  let!(:user) { create(:confirmed_user, :with_home) }
  let!(:attribute_type) { create(:attrib_type, name: 'MyImageTemplates') }
  let(:attribute) { create(:attrib, project: user.home_project) }

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

        scenario 'it is not possible to add an attribute, the link is not shown' do
          login other_user

          visit index_attribs_path(project: user.home_project_name)
          expect(page).not_to have_content('Add a new attribute')
        end
      end

      context 'with permissions' do
        scenario 'remove attribute' do
          login user

          visit index_attribs_path(project: user.home_project_name)
          click_link 'Delete attribute'
          expect(find('#delete-attribute-modal')).to have_text('Delete attribute?')
          within('#delete-attribute-modal .modal-footer') do
            expect(page).to have_button('Delete')
            click_button('Delete')
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

      scenario 'add attribute with values' do
        login user

        add_attribute_with_values(package)
        expect(page).to have_content('Attribute was successfully updated.')

        visit index_attribs_path(project: user.home_project_name, package: package.name)
        attribute_type_value = page.all('#attributes tr td', exact_text: attribute_type.fullname)[0].sibling('td', match: :first).text
        expect(attribute_type_value).to eq("test\n2nd line\ntest 1")
      end
    end
  end
end
