require 'browser_helper'

RSpec.feature 'Bootstrap_Repositories', type: :feature, js: true, vcr: true do
  let(:admin_user) { create(:admin_user) }
  let!(:repository) { create(:repository) }

  describe 'Repositories Flags' do
    let!(:user) { create(:confirmed_user, :with_home, login: 'Jane') }
    let(:project) { user.home_project }

    include_examples 'bootstrap tests for sections with flag tables'
  end

  describe 'Repositories' do
    before do
      login admin_user

      fake_distribution_body = File.open(Rails.root.join('test/fixtures/backend/distributions.xml')).read

      stub_request(:get, 'https://api.opensuse.org/public/distributions.xml').
        to_return(status: 200, body: fake_distribution_body, headers: {})
    end

    scenario 'add/delete repository from distribution' do
      # Create interconnect
      visit(repositories_distributions_path(project: admin_user.home_project))
      click_button('Connect', match: :first)

      visit(repositories_distributions_path(project: admin_user.home_project))
      find("label[for='repo_openSUSE_Tumbleweed']").click
      expect(page).to have_text("Successfully added repository 'openSUSE_Tumbleweed'")

      visit(project_repositories_path(project: admin_user.home_project))

      expect(page).to have_css('.repository-card')

      within '.repository-card' do
        expect(page).to have_link('openSUSE_Tumbleweed')
        expect(page).to have_link('Edit Repository')
        expect(page).to have_link('Add Repository Path')
        expect(page).to have_link('Download Repository')
        expect(page).to have_link('Delete Repository')
        # Repository path
        expect(page).to have_text('openSUSE.org/snapshot')
      end

      visit(repositories_distributions_path(project: admin_user.home_project))
      find("label[for='repo_openSUSE_Tumbleweed']").click
      expect(page).to have_text("Successfully removed repository 'openSUSE_Tumbleweed'")

      visit(project_repositories_path(project: admin_user.home_project))

      expect(page).not_to have_link('openSUSE_Tumbleweed')
    end

    scenario 'add repository from project' do
      visit(project_repositories_path(project: admin_user.home_project))

      click_link('Add from a Project')
      fill_in('target_project', with: repository.project)
      # Select the first autocomplete result
      find('.ui-menu-item-wrapper', match: :first).click
      # Remove focus from autocomplete. Needed to trigger update of the other input fields.
      find('#target_repo').click

      click_button('Accept')

      expect(page).to have_css('.repository-card')

      within '.repository-card' do
        expect(page).to have_link("#{repository.project}_#{repository}")
        expect(page).to have_link('Edit Repository')
        expect(page).to have_link('Add Repository Path')
        expect(page).to have_link('Download Repository')
        expect(page).to have_link('Delete Repository')
        # Repository path
        expect(page).to have_text("#{repository.project}/#{repository}")
      end
    end
  end
end
