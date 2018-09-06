require 'browser_helper'

RSpec.feature 'Bootstrap_Projects', type: :feature, js: true, vcr: true do
  let!(:user) { create(:confirmed_user, login: 'Jane') }
  let(:project) { user.home_project }

  describe 'creating packages in projects owned by user, eg. home projects' do
    let(:very_long_description) { Faker::Lorem.paragraph(20) }

    before do
      login user
      visit project_show_path(project: user.home_project)
      click_link('Create package')
    end

    scenario 'with valid data' do
      expect(page).to have_text("Create New Package for #{user.home_project_name}")

      fill_in 'name', with: 'coolstuff'
      fill_in 'title', with: 'cool stuff everyone needs'
      fill_in 'description', with: very_long_description
      click_button 'Save changes'

      expect(page).to have_text("Package 'coolstuff' was created successfully")
      expect(page).to have_current_path(package_show_path(project: user.home_project_name, package: 'coolstuff'))
      expect(find(:css, '#package-title')).to have_text('cool stuff everyone needs')
      expect(find(:css, '#description-text')).to have_text(very_long_description)
    end
  end
end
