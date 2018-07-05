require 'browser_helper'
require 'ldap'

RSpec.feature 'Login', type: :feature, js: true do
  let!(:user) { create(:confirmed_user, login: 'proxy_user') }

  scenario 'login with home project shows a link to it' do
    login user
    within('#subheader') do
      expect(page).to have_link('Home Project')
    end
  end

  scenario 'login without home project shows a link to create it' do
    user.home_project.destroy
    login user
    within('#subheader') do
      expect(page).to have_link('Create Home')
    end
  end

  scenario 'login via login page' do
    visit session_new_path
    fill_in 'Username', with: user.login
    fill_in 'Password', with: 'buildservice'
    click_button('Log In')

    expect(find('#link-to-user-home').text).to eq user.login
  end

  scenario 'login via widget' do
    visit root_path
    click_link('Log In')

    within('div#login-form') do
      fill_in 'Username', with: user.login
      fill_in 'Password', with: 'buildservice'
      click_button('Log In')
    end

    expect(find('#link-to-user-home').text).to eq user.login
  end

  scenario 'login with wrong data' do
    visit root_path
    click_link('Log In')

    within('#login-form') do
      fill_in 'Username', with: user.login
      fill_in 'Password', with: 'foo'
      click_button 'Log In'
    end

    expect(page).to have_content('Authentication failed')
  end

  scenario 'logout' do
    login(user)

    within('div#subheader') do
      click_link('Logout')
    end

    expect(page).not_to have_css('a#link-to-user-home')
    expect(page).to have_link('Log')
  end

  context 'in ldap mode' do
    include_context 'setup ldap mock with user mock'
    include_context 'an ldap connection'

    let(:ldap_user) { double(:ldap_user, to_hash: { 'dn' => 'tux', 'sn' => ['John', 'Smith'] }) }

    before do
      stub_const('CONFIG', CONFIG.merge('ldap_mode'         => :on,
                                        'ldap_search_user'  => 'tux',
                                        'ldap_search_auth'  => 'tux_password',
                                        'ldap_ssl'          => :off,
                                        'ldap_authenticate' => :ldap))

      allow(ldap_mock).to receive(:search).and_yield(ldap_user)
      allow(ldap_mock).to receive(:unbind)

      allow(ldap_user_mock).to receive(:bind).with('tux', 'tux_password')
      allow(ldap_user_mock).to receive(:bound?).and_return(true)
      allow(ldap_user_mock).to receive(:search).and_yield(ldap_user)
      allow(ldap_user_mock).to receive(:unbind)
    end

    it 'allows the user to login via the webui' do
      visit session_new_path
      fill_in 'Username', with: 'tux'
      fill_in 'Password', with: 'tux_password'
      click_button('Log In')

      expect(find('#link-to-user-home').text).to eq 'tux'
      expect(page).to have_content('Logout')
    end
  end
end
