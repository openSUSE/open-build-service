require 'browser_helper'

RSpec.describe 'Package Templates', :vcr do
  let(:user) { create(:confirmed_user, :with_home, login: 'tom') }
  let(:admin) { create(:admin_user) }
  let(:project) { user.home_project }
  let(:template_project) do
    login admin
    prj = create(:project, name: 'templates')
    create(:attrib, attrib_type: AttribType.find_by_namespace_and_name!('OBS', 'PackageTemplates'), project: prj)
    prj
  end
  let!(:template) { create(:package_with_templates, name: 'template', project: template_project) }

  describe 'creates a new package from a template' do
    let(:name) { 'template_1' }

    before do
      login user
      visit project_show_path(project)
      click_on('Create Package')
      fill_in 'package[name]', with: name
      fill_in 'package[title]', with: Faker::Lorem.sentence
      fill_in 'package[description]', with: Faker::Lorem.paragraph
      select(template.title, from: 'Template')
      click_on 'Create'
    end

    it 'has all the files' do
      expect(page).to have_text("#{name}.spec")
      expect(page).to have_text("#{name}.changes")
      expect(page).to have_text("#{project.name}.test")
    end
  end
end
