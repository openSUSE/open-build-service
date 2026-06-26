require 'browser_helper'

RSpec.describe 'Watchlists', :js, :vcr do
  let(:user) { create(:confirmed_user, :with_home, login: 'kody') }
  let(:project_a) { create(:project, name: 'watchlist_test_project_a') }
  let(:project_b) { create(:project, name: 'watchlist_test_project_b') }
  let(:package) { create(:package, project: project_a, name: 'watchlist_test_package') }
  let(:request) { create(:bs_request_with_submit_action) }

  it 'add and remove items from watchlist' do
    login user

    visit project_show_path(project: project_a)
    click_link('Watchlist')
    expect(page).to have_text('Projects you are watching')
    expect(page).to have_text('There are no projects in the watchlist yet')
    expect(page).to have_text('There are no packages in the watchlist yet')
    expect(page).to have_text('There are no requests in the watchlist yet')

    # Add project
    click_link('Watch this project')
    within('.watchlist-collapse') do
      expect(page).to have_no_text('There are no projects in the watchlist yet')
      expect(page).to have_text('Remove this project from Watchlist')
      expect(page).to have_text(project_a.name)
    end

    # Add another project
    visit project_show_path(project: project_b)
    click_link('Watchlist')
    click_link('Watch this project')
    within('.watchlist-collapse') do
      expect(page).to have_text('Remove this project from Watchlist')
      expect(page).to have_text(project_a.name)
      expect(page).to have_text(project_b.name)
    end

    # Add package
    visit package_show_path(project: project_a.name, package: package.name)
    click_link('Watchlist')
    click_link('Watch this package')
    within('.watchlist-collapse') do
      expect(page).to have_text('Remove this package from Watchlist')
      expect(page).to have_text(project_a.name)
      expect(page).to have_text(project_b.name)
      expect(page).to have_text(package.name)
    end

    # Add request
    visit request_show_path(number: request.number)
    click_link('Watchlist')
    click_link('Watch this request')
    within('.watchlist-collapse') do
      expect(page).to have_text('Remove this request from Watchlist')
      expect(page).to have_text(project_a.name)
      expect(page).to have_text(project_b.name)
      expect(page).to have_text(package.name)
      expect(page).to have_text("##{request.number} Submit")
    end

    # Remove request
    click_link('Remove this request from Watchlist')
    within('#delete-item-from-watchlist-modal') do
      click_button('Remove')
    end
    within('.watchlist-collapse') do
      expect(page).to have_text(project_a.name)
      expect(page).to have_text(project_b.name)
      expect(page).to have_text(package.name)
      expect(page).to have_no_text("##{request.number} Submit")
    end
  end
end
