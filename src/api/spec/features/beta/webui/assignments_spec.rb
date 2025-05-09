require 'browser_helper'

RSpec.describe 'Assignments', :vcr do
  before do
    Flipper.enable(:foster_collaboration)
  end

  describe 'showing the assigment of a package' do
    let!(:user) { create(:confirmed_user, :with_home, login: 'tom') }
    let!(:package) { create(:package_with_file, name: 'test_package', project: user.home_project) }

    context 'when having no assignment' do
      it 'shows nothing' do
        login(user)
        visit package_show_path(user.home_project, package)
        expect(page).to have_css('ul.side_links')
        expect(page).to(have_no_text('Assigned'))
      end
    end

    context 'when having an assignment' do
      let(:assignee) { create(:confirmed_user, login: 'mal') }

      it 'shows the login name of the assigned user' do
        create(:assignment, assignee: assignee, package: package)
        login(user)
        visit package_show_path(user.home_project, package)
        expect(page).to have_text('Assigned to: mal')
      end
    end
  end
end
