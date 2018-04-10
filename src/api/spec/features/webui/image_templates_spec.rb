# frozen_string_literal: true
require 'browser_helper'
# WARNING: This test require real backend answers for projects/packages, make
# sure you uncomment this line and start a test backend.
# CONFIG['global_write_through'] = true

RSpec.feature 'ImageTemplates', type: :feature, js: true do
  let!(:user) { create(:confirmed_user, login: 'tom') }

  context 'branching' do
    let!(:project) { create(:project, name: 'my_project') }
    let!(:package1) { create(:package_with_file, project: project, name: 'first_package',  title: 'a') }
    let!(:package2) { create(:package_with_file, project: project, name: 'second_package', title: 'c') }
    let!(:package3) { create(:package_with_file, project: project, name: 'third_package',  title: 'b') }
    let!(:kiwi_image) { create(:kiwi_image_with_package, with_kiwi_file: true, project: project) }
    let(:kiwi_package) { kiwi_image.package }
    let!(:attrib) { create(:template_attrib, project: project) }

    scenario 'branch image template' do
      visit image_templates_path
      expect(page).to have_css('input.create_appliance[disabled]')

      login(user)
      visit root_path
      find('.proceed_text > a', text: 'New Image').click

      expect(page).to have_text(package1.title)
      expect(find("input[data-package='#{package1}']", visible: false)['checked']).to be true
      expect(find("input[data-package='#{package3}']", visible: false)['checked']).to be false
      expect(find("input[data-package='#{package2}']", visible: false)['checked']).to be false
      expect(find("input[data-package='#{kiwi_package}']", visible: false)['checked']).to be false

      expect(page).to have_field('target_package', with: package1)
      find("input[data-package='#{package2}']", visible: false).trigger(:click)
      expect(page).to have_field('target_package', with: package2)
      fill_in 'target_package', with: 'custom_name'

      click_button('Create appliance')
      find('#package_tabs')
      expect(page).to have_text('Successfully branched package')
      expect(page).to have_text('home:tom:branches:my_project > custom_name')
    end

    scenario 'branch Kiwi image template' do
      visit image_templates_path
      expect(page).to have_css('input.create_appliance[disabled]')

      login(user)
      visit root_path
      find('.proceed_text > a', text: 'New Image').click

      expect(page).to have_text(package1.title)
      expect(find("input[data-package='#{package1}']", visible: false)['checked']).to be true
      expect(find("input[data-package='#{package3}']", visible: false)['checked']).to be false
      expect(find("input[data-package='#{package2}']", visible: false)['checked']).to be false
      expect(find("input[data-package='#{kiwi_package}']", visible: false)['checked']).to be false

      expect(page).to have_field('target_package', with: package1)
      find("input[data-package='#{kiwi_package}']", visible: false).trigger(:click)
      expect(page).to have_field('target_package', with: kiwi_package)
      fill_in 'target_package', with: 'package_with_kiwi_image'

      click_button('Create appliance')
      find('#kiwi-image-update-form')
      expect(page).to have_text('home:tom:branches:my_project > package_with_kiwi_image')
    end
  end

  context 'feature switch' do
    context 'privileged user' do
      let(:admin) { create(:admin_user, login: 'admin') }
      before do
        login admin
      end

      scenario 'disabled' do
        Feature.run_with_deactivated(:image_templates) do
          visit root_path
          expect(page).to have_link('New Image')
          visit image_templates_path
          expect(page.status_code).to eq(200)
        end
      end
    end

    context 'unprivileged user' do
      before do
        login user
      end

      scenario 'enabled' do
        Feature.run_with_activated(:image_templates) do
          visit root_path
          expect(page).to have_link('New Image')
          visit image_templates_path
          expect(page.status_code).to eq(200)
        end
      end

      scenario 'disabled' do
        Feature.run_with_deactivated(:image_templates) do
          visit root_path
          expect(page).not_to have_link('New Image')
          visit image_templates_path
          expect(page.status_code).to eq(404)
        end
      end
    end
  end
end
