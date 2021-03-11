require 'browser_helper'

RSpec.describe 'ImageTemplates', type: :feature, js: true do
  let!(:user) { create(:confirmed_user, :with_home, login: 'tom') }

  context 'branching' do
    let!(:project) { create(:project, name: 'my_project') }
    let!(:package1) { create(:package_with_file, project: project, name: 'first_package',  title: 'a') }
    let!(:package2) { create(:package_with_file, project: project, name: 'second_package', title: 'c') }
    let!(:package3) { create(:package_with_file, project: project, name: 'third_package',  title: 'b') }
    let!(:kiwi_image) { create(:kiwi_image_with_package, with_kiwi_file: true, project: project) }
    let(:kiwi_package) { kiwi_image.package }
    let(:attrib) { create(:template_attrib, project: project) }

    before do
      # create attrib as user
      User.session = user
      attrib
      User.session = nil
    end

    it 'branch image template' do
      visit image_templates_path
      expect(page).to have_css('input[type=submit][disabled]')

      login(user)
      visit project_show_path(user.home_project)
      desktop? ? click_link('New Image') : click_menu_link('Actions', 'New Image')

      expect(page).to have_text(package1.title)
      expect(page).to have_selector("input[data-package='#{package1}']:checked", visible: :hidden)
      expect(page).to have_selector("input[data-package='#{package2}']:not(:checked)", visible: :hidden)
      expect(page).to have_selector("input[data-package='#{package3}']:not(:checked)", visible: :hidden)
      expect(page).to have_selector("input[data-package='#{kiwi_package}']:not(:checked)", visible: :hidden)

      expect(page).to have_field('target_package', with: package1)
      within :xpath, "//input[@data-package='#{package2}']/../label" do
        find('.description').click
      end
      expect(page).to have_field('target_package', with: package2)
      fill_in 'target_package', with: 'custom_name'

      click_button('Create appliance')
      find('body')
      expect(page).to have_text('Successfully branched package')
      expect(page).to have_text("home:tom:branches:my_project\ncustom_name")
    end

    it 'branch Kiwi image template' do
      # FIXME: This scenario is flickering on mobile
      skip('This scenario fails most of the time') if mobile?

      visit image_templates_path
      expect(page).to have_css('input[type=submit][disabled]')

      login(user)
      visit project_show_path(user.home_project)
      click_link('New Image')

      expect(page).to have_text(package1.title)
      expect(page).to have_selector("input[data-package='#{package1}']:checked", visible: :hidden)
      expect(page).to have_selector("input[data-package='#{package2}']:not(:checked)", visible: :hidden)
      expect(page).to have_selector("input[data-package='#{package3}']:not(:checked)", visible: :hidden)
      expect(page).to have_selector("input[data-package='#{kiwi_package}']:not(:checked)", visible: :hidden)

      expect(page).to have_field('target_package', with: package1)
      within :xpath, "//input[@data-package='#{kiwi_package}']/../label" do
        find('.description').click
      end
      expect(page).to have_field('target_package', with: kiwi_package)

      fill_in 'target_package', with: 'package_with_kiwi_image'

      click_button('Create appliance')
      expect(page).to have_text("home:tom:branches:my_project\npackage_with_kiwi_image")
    end
  end
end
