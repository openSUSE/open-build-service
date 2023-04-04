require 'browser_helper'

RSpec.describe 'Patchinfo', js: true, vcr: true do
  let(:user) { create(:confirmed_user, :with_home, login: 'tom') }
  let(:project) { user.home_project }

  describe 'create Patchinfo' do
    it 'form incomplete' do
      login user
      visit project_show_path(user.home_project)
      desktop? ? click_link('Create Patchinfo') : click_menu_link('Actions', 'Create Patchinfo')
      expect(page).to have_current_path(edit_patchinfo_path(project: project, package: 'patchinfo'))
      expect(page).to have_text("Edit Patchinfo for #{project.name}")
      fill_in 'patchinfo[summary]', with: 'A' * 9
      fill_in 'patchinfo[description]', with: 'A' * 30
      click_button 'Save'
      # We check this field using 'minlength' HTML5 control. It opens a tooltip and the error message inside can vary depending on the browser,
      # so we just check its presence and not its content like follows.
      message = page.find_by_id('patchinfo_summary').native.attribute('validationMessage')
      expect(message).not_to be_empty
      message = page.find_by_id('patchinfo_description').native.attribute('validationMessage')
      expect(message).not_to be_empty
    end

    it 'form complete' do
      login user
      visit project_show_path(user.home_project)
      desktop? ? click_link('Create Patchinfo') : click_menu_link('Actions', 'Create Patchinfo')
      expect(page).to have_current_path(edit_patchinfo_path(project: project, package: 'patchinfo'))
      expect(page).to have_text("Edit Patchinfo for #{project.name}")
      fill_in 'patchinfo[summary]', with: 'A' * 15
      fill_in 'patchinfo[description]', with: 'A' * 55
      click_button 'Save'
      expect(page).to have_current_path(show_patchinfo_path(project: project, package: 'patchinfo'))
      expect(page).to have_text('Successfully edited patchinfo')
    end
  end

  describe 'delete Patchinfo' do
    let(:patchinfo_package) do
      Patchinfo.new.create_patchinfo(user.home_project_name, nil) unless user.home_project.packages.exists?(name: 'patchinfo')
      Package.get_by_project_and_name(user.home_project_name, 'patchinfo', use_source: false)
    end

    before do
      login(user)
      patchinfo_package
    end

    it 'delete' do
      visit show_patchinfo_path(project: project, package: 'patchinfo')
      expect(page).to have_link('Delete patchinfo')
      click_link('Delete patchinfo')
      within('#delete-patchinfo-modal') do
        expect(page).to have_text('Do you really want')
        click_button('Delete')
      end
      expect(page).to have_text('Patchinfo was successfully removed.')
    end
  end
end
