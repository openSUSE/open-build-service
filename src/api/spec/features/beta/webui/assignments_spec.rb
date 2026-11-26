require 'browser_helper'

RSpec.describe 'Assignments', :vcr do
  let!(:user) { create(:confirmed_user, :with_home, login: 'tom') }
  let(:assignee) { create(:confirmed_user, login: 'mal') }
  let!(:package) { create(:package_with_maintainer, name: 'test_package', project: user.home_project, maintainer: assignee) }

  before do
    Flipper.enable(:foster_collaboration)
    login(user)
  end

  describe 'showing the assigment of a package' do
    context 'when having no assignment' do
      it 'shows nothing' do
        visit package_show_path(user.home_project, package)
        expect(page).to have_css('ul.side_links')
        expect(page).to(have_no_text('Assigned'))
      end
    end

    context 'when having an assignment' do
      it 'shows the login name of the assigned user' do
        create(:assignment, assignee: assignee, package: package)
        visit package_show_path(user.home_project, package)
        expect(page).to have_text('Assigned to:')
      end
    end
  end

  describe 'creating an assignment for a package' do
    before do
      assignee
      visit package_show_path(user.home_project, package)
    end

    it 'creates an assignment for the package' do
      click_button('Assign someone')
      fill_in('assignments_search', with: 'mal')
      find('.ui-menu-item-wrapper', text: assignee.login, exact_text: true).click
      click_button('Assign')
      expect(page).to have_text('Assigned to:')
    end
  end

  describe 'unassigning a package' do
    before do
      assignee
      create(:assignment, assignee: assignee, package: package)
    end

    it 'removes the assignment' do
      visit package_show_path(user.home_project, package)
      accept_alert { click_link('remove-assignment') }
      expect(page).to have_css('ul.side_links')
      expect(page).to(have_no_text('Assigned'))
    end
  end
end
