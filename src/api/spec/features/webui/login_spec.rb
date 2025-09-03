require 'browser_helper'

RSpec.describe 'Login', :js do
  let!(:user) { create(:confirmed_user, :with_home, login: 'proxy_user') }
  let(:admin) { create(:admin_user) }

  it 'login via login page' do
    visit new_session_path

    within('#loginform') do
      fill_in 'username', with: user.login
      fill_in 'password', with: 'buildservice'
      click_button('Log In')
    end

    expect(page).to have_link('Profile', visible: :all)
  end

  it 'login via widget' do
    visit user_path(user)
    within(desktop? ? '#top-navigation-area' : '#bottom-navigation-area') do
      click_link('Log In')
    end

    within('#log-in-modal') do
      fill_in 'username', with: user.login
      fill_in 'password', with: 'buildservice'
      click_button('Log In')
    end

    expect(page).to have_link('Your Home Project', visible: :all)
  end

  it 'login with wrong data' do
    visit user_path(user)
    within(desktop? ? '#top-navigation-area' : '#bottom-navigation-area') do
      click_link('Log In')
    end

    within('#log-in-modal') do
      fill_in 'username', with: user.login
      fill_in 'password', with: 'foo'
      click_button('Log In')
    end

    expect(page).to have_content('Authentication failed')
  end

  it 'logout' do
    login(user)

    visit user_path(user)
    if desktop?
      click_link(id: 'top-navigation-profile-dropdown')
      within('#top-navigation-area') do
        click_link('Logout')
      end
    else
      click_menu_link('Places', 'Logout')
    end

    expect(page).to have_no_css('a#link-to-user-home')
    expect(page).to have_link('Log')
  end
end
