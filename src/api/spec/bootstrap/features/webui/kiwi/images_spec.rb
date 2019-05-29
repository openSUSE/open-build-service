require 'browser_helper'

RSpec.feature 'Bootstrap_Kiwi_Images', type: :feature, js: true, vcr: true do
  let(:user) { create(:confirmed_user, login: 'tom') }

  before do
    login(user)
  end

  context 'project with wiki image' do
    let(:kiwi_image) { create(:kiwi_image_with_package, with_kiwi_file: true, project: user.home_project, package_name: 'package_with_kiwi_file') }

    scenario 'modify author' do
      visit package_show_path(project: user.home_project, package: kiwi_image.package)
      click_link('View Image')

      click_link('Details')
      click_link('Edit details')
      fill_in 'kiwi_image_description_attributes_author', with: 'custom_author'
      click_link('Continue')
      find('#kiwi-image-update-form-save').click

      within('#kiwi-description') do
        expect(page).to have_text('Author: custom_author')
      end
    end
  end
end
