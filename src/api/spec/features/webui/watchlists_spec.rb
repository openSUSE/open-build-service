require 'browser_helper'

RSpec.describe 'Watchlists', type: :feature, js: true, vcr: true do
  let(:user) { create(:confirmed_user, :with_home, login: 'kody') }
  let(:project) { create(:project, name: 'watchlist_test_project') }
  let(:user_with_watched_project) do
    other_user = create(:confirmed_user, login: 'brian')
    other_user.watched_projects << create(:watched_project,
                                          project: create(:project, name: "#{other_user.login}_s_watched_project"))
    other_user
  end

  it 'add projects to watchlist' do
    login user
    visit project_show_path(user.home_project)

    click_on('Watchlist')
    expect(page).to have_content('Projects you are watching')
    expect(page).to have_css('.list-group .list-group-item', count: 0)

    expect(page).to have_css('#toggle-watch', text: 'Watch this project')
    click_link('Watch this project')

    click_on('Watchlist')
    expect(page).to have_css('.list-group .list-group-item a', text: user.home_project_name)
    expect(page).to have_css('.list-group .list-group-item', count: 1)

    visit project_show_path(project: project.name)
    click_on('Watchlist')
    expect(page).to have_css('#toggle-watch', text: 'Watch this project')
    click_link('Watch this project')

    click_on('Watchlist')
    expect(page).to have_css('.list-group .list-group-item a', text: user.home_project_name)
    expect(page).to have_css('.list-group .list-group-item a', text: project.name)
    expect(page).to have_css('.list-group .list-group-item', count: 2)
  end

  it 'remove projects from watchlist' do
    login user_with_watched_project
    visit project_show_path(project: 'brian_s_watched_project')

    click_on('Watchlist')
    expect(page).to have_content('Projects you are watching')
    expect(page).to have_css('.list-group .list-group-item a', text: 'brian_s_watched_project')
    expect(page).to have_css('.list-group .list-group-item', count: 1)
    expect(page).to have_css('#toggle-watch', text: 'Remove this project from Watchlist')

    click_link('Remove this project from Watchlist')

    visit project_show_path(project: 'brian_s_watched_project')
    click_on('Watchlist')
    expect(page).to have_css('.list-group .list-group-item', count: 0)
    expect(page).to have_css('#toggle-watch', text: 'Watch this project')
  end
end
