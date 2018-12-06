require 'browser_helper'

RSpec.feature 'Bootstrap_Projects', type: :feature, js: true, vcr: true do
  let!(:user) { create(:confirmed_user, login: 'Jane') }
  let(:project) { user.home_project }
  let!(:admin_user) { create(:admin_user) }
  describe 'creating packages in projects owned by user, eg. home projects' do
    let(:very_long_description) { Faker::Lorem.paragraph(20) }

    before do
      login user
      visit project_show_path(project: user.home_project)
      click_link('Create Package')
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

  describe 'DoD Repositories' do
    let(:project_with_dod_repo) { create(:project) }
    let(:repository) { create(:repository, project: project_with_dod_repo) }
    let!(:download_repository) { create(:download_repository, repository: repository) }

    before do
      login admin_user
    end

    scenario 'adding DoD repositories via meta editor' do
      fixture_file = File.read(Rails.root + 'test/fixtures/backend/download_on_demand/project_with_dod.xml').
                     gsub('user5', admin_user.login)

      visit(project_meta_path(project: admin_user.home_project_name))
      page.evaluate_script("editors[0].setValue(\"#{fixture_file.gsub("\n", '\n')}\");")
      click_button('Save')
      expect(page).to have_css('#flash', text: 'Config successfully saved!')

      visit(project_repositories_path(project: admin_user.home_project_name))
      within '.repository-container' do
        expect(page).to have_link('standard')
        expect(page).to have_link('Delete repository')
        expect(page).to have_text('Download on demand sources')
        expect(page).to have_link('Add')
        expect(page).to have_link('Edit')
        expect(page).to have_link('Delete')
        expect(page).to have_link('http://mola.org2')
        expect(page).to have_text('rpmmd')
      end
    end
  end
end
