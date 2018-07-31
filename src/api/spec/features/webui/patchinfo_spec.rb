require 'browser_helper'

# CONFIG['global_write_through'] = true

RSpec.feature 'Patchinfo', type: :feature, js: true do
  let(:user) { create(:confirmed_user, login: 'tom') }
  let(:project) { user.home_project }

  feature 'create Patchinfo' do
    scenario 'form incomplete' do
      login user
      visit project_show_path(user.home_project)
      expect(page).to have_link('Create patchinfo')
      click_link('Create patchinfo')
      expect(page).to have_current_path(patchinfo_new_patchinfo_path(project: project))
      expect(page).to have_text("Patchinfo-Editor for #{project.name}")
      fill_in 'summary', with: 'A' * 9
      fill_in 'description', with: 'A' * 30
      click_button 'Save Patchinfo'
      expect(page).to have_text('|| Summary is too short (should have more than 10 signs)')
      expect(page).to have_text('|| Description is too short (should have more than 50 signs and longer than summary)')
    end

    scenario 'form complete' do
      login user
      visit project_show_path(user.home_project)
      expect(page).to have_link('Create patchinfo')
      click_link('Create patchinfo')
      expect(page).to have_current_path(patchinfo_new_patchinfo_path(project: project))
      expect(page).to have_text("Patchinfo-Editor for #{project.name}")
      fill_in 'summary', with: 'A' * 15
      fill_in 'description', with: 'A' * 55
      click_button 'Save Patchinfo'
      expect(page).to have_current_path(patchinfo_show_path(project: project, package: 'patchinfo'))
      expect(page).to have_text('Successfully edited patchinfo')
    end
  end

  feature 'delete Patchinfo' do
    given(:patchinfo_package) do
      Patchinfo.new.create_patchinfo(user.home_project_name, nil) unless user.home_project.packages.where(name: 'patchinfo').exists?
      Package.get_by_project_and_name(user.home_project_name, 'patchinfo', use_source: false)
    end

    scenario 'delete' do
      login user
      patchinfo_package
      visit patchinfo_show_path(project: project, package: 'patchinfo')
      expect(page).to have_link('Delete patchinfo')
      click_link('Delete patchinfo')
      expect(page).to have_text('Do you really want')
      click_button('Ok')
      expect(page).to have_text('Patchinfo was successfully removed.')
    end
  end
end
