require 'browser_helper'

RSpec.describe 'Watchlists', js: true, vcr: true do
  let(:user) { create(:confirmed_user, :with_home, login: 'kody') }
  let(:project_a) { create(:project, name: 'watchlist_test_project_a') }
  let(:project_b) { create(:project, name: 'watchlist_test_project_b') }
  let(:package) { create(:package, project: project_a, name: 'watchlist_test_package') }
  let(:request) { create(:bs_request_with_submit_action) }

  it 'add and remove items from watchlist' do
    login user

    visit project_show_path(project: project_a)
    click_on('Watchlist')
    expect(page).to have_content('Projects you are watching')
    expect(page).to have_content('There are no projects in the watchlist yet')
    expect(page).to have_content('There are no packages in the watchlist yet')
    expect(page).to have_content('There are no requests in the watchlist yet')

    # Add project
    click_link('Watch this project')
    within('.watchlist-collapse') do
      expect(page).not_to have_content('There are no projects in the watchlist yet')
      expect(page).to have_content('Remove this project from Watchlist')
      expect(page).to have_content(project_a.name)
    end

    # Add another project
    visit project_show_path(project: project_b)
    click_on('Watchlist')
    click_link('Watch this project')
    within('.watchlist-collapse') do
      expect(page).to have_content('Remove this project from Watchlist')
      expect(page).to have_content(project_a.name)
      expect(page).to have_content(project_b.name)
    end

    # Add package
    visit package_show_path(project: project_a.name, package: package.name)
    click_on('Watchlist')
    click_link('Watch this package')
    within('.watchlist-collapse') do
      expect(page).to have_content('Remove this package from Watchlist')
      expect(page).to have_content(project_a.name)
      expect(page).to have_content(project_b.name)
      expect(page).to have_content(package.name)
    end

    # Add request
    visit request_show_path(number: request.number)
    click_on('Watchlist')
    click_link('Watch this request')
    within('.watchlist-collapse') do
      expect(page).to have_content('Remove this request from Watchlist')
      expect(page).to have_content(project_a.name)
      expect(page).to have_content(project_b.name)
      expect(page).to have_content(package.name)
      expect(page).to have_content("##{request.number} Submit")
    end

    # Remove request
    click_link('Remove this request from Watchlist')
    within('#delete-item-from-watchlist-modal') do
      click_button('Remove')
    end
    within('.watchlist-collapse') do
      expect(page).to have_content(project_a.name)
      expect(page).to have_content(project_b.name)
      expect(page).to have_content(package.name)
      expect(page).not_to have_content("##{request.number} Submit")
    end
  end
end
