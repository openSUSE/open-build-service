require 'browser_helper'

RSpec.feature 'Watchlists', type: :feature, js: true do
  let(:user) { create(:confirmed_user, login: 'kody') }
  let(:project) { create(:project, name: 'watchlist_test_project') }
  let(:user_with_watched_project) do
    other_user = create(:confirmed_user, login: 'brian')
    other_user.watched_projects << create(:watched_project,
                                          project: create(:project, name: "#{other_user.login}_s_watched_project"))
    other_user
  end

  scenario 'add projects to watchlist' do
    login user
    visit project_show_path(user.home_project)

    click_on('Watchlist')
    expect(page).to have_content('List of projects you are watching')
    expect(page).to have_css('a.dropdown-item.project-link', count: 0)

    expect(page).to have_css('#toggle-watch', text: 'Add this project to Watchlist')
    find('#toggle-watch').click

    click_on('Watchlist')
    expect(page).to have_css('a.dropdown-item.project-link', text: user.home_project_name)
    expect(page).to have_css('a.dropdown-item.project-link', count: 1)

    visit project_show_path(project: project.name)
    click_on('Watchlist')
    expect(page).to have_css('#toggle-watch', text: 'Add this project to Watchlist')
    find('#toggle-watch').click

    click_on('Watchlist')
    expect(page).to have_css('a.dropdown-item.project-link', text: user.home_project_name)
    expect(page).to have_css('a.dropdown-item.project-link', text: project.name)
    expect(page).to have_css('a.dropdown-item.project-link', count: 2)
  end

  scenario 'remove projects from watchlist' do
    login user_with_watched_project
    visit project_show_path(project: 'brian_s_watched_project')

    click_on('Watchlist')
    expect(page).to have_content('List of projects you are watching')
    expect(page).to have_css('a.dropdown-item.project-link', text: 'brian_s_watched_project')
    expect(page).to have_css('a.dropdown-item.project-link', count: 1)
    expect(page).to have_css('#toggle-watch', text: 'Remove this project from Watchlist')

    find('#toggle-watch').click

    visit project_show_path(project: 'brian_s_watched_project')
    click_on('Watchlist')
    expect(page).to have_css('a.dropdown-item.project-link', count: 0)
    expect(page).to have_css('#toggle-watch', text: 'Add this project to Watchlist')
  end
end
