require 'browser_helper'

# CONFIG['global_write_through'] = true

RSpec.feature 'Patchinfo', type: :feature, js: true do
  let(:user) { create(:confirmed_user, :with_home, login: 'tom') }
  let(:project) { user.home_project }

  feature 'create Patchinfo' do
    scenario 'form incomplete' do
      login user
      visit project_show_path(user.home_project)
      expect(page).to have_link('Create Patchinfo')
      click_link('Create Patchinfo')
      expect(page).to have_current_path(edit_patchinfo_path(project: project, package: 'patchinfo'))
      expect(page).to have_text("Edit Patchinfo for #{project.name}")
      fill_in 'patchinfo[summary]', with: 'A' * 9
      fill_in 'patchinfo[description]', with: 'A' * 30
      click_button 'Save'
      # We check this field using 'minlength' HTML5 control. It opens a tooltip and the error message inside can vary depending on the browser,
      # so we just check its presence and not its content like follows.
      message = page.find('#patchinfo_summary').native.attribute('validationMessage')
      expect(message).not_to be_empty
      message = page.find('#patchinfo_description').native.attribute('validationMessage')
      expect(message).not_to be_empty
    end

    scenario 'form complete' do
      login user
      visit project_show_path(user.home_project)
      expect(page).to have_link('Create Patchinfo')
      click_link('Create Patchinfo')
      expect(page).to have_current_path(edit_patchinfo_path(project: project, package: 'patchinfo'))
      expect(page).to have_text("Edit Patchinfo for #{project.name}")
      fill_in 'patchinfo[summary]', with: 'A' * 15
      fill_in 'patchinfo[description]', with: 'A' * 55
      click_button 'Save'
      expect(page).to have_current_path(patchinfo_show_path(project: project, package: 'patchinfo'))
      expect(page).to have_text('Successfully edited patchinfo')
    end
  end
end
