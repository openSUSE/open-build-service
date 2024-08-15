require 'browser_helper'

RSpec.feature 'Bootstrap_Patchinfo', type: :feature, js: true, vcr: true do
  let(:user) { create(:confirmed_user, :with_home, login: 'tom') }
  let(:project) { user.home_project }

  feature 'delete Patchinfo' do
    let(:patchinfo_package) do
      Patchinfo.new.create_patchinfo(user.home_project_name, nil) unless user.home_project.packages.where(name: 'patchinfo').exists?
      Package.get_by_project_and_name(user.home_project_name, 'patchinfo', use_source: false)
    end

    before do
      login(user)
      patchinfo_package
    end

    scenario 'delete' do
      visit patchinfo_show_path(project: project, package: 'patchinfo')
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
