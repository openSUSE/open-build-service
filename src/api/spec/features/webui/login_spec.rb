require 'browser_helper'
require 'gssapi'
require 'ldap'

RSpec.feature 'Login', type: :feature, js: true do
  let!(:user) { create(:confirmed_user, login: 'proxy_user') }

  context 'In proxy mode' do
    before do
      # Fake proxy mode
      stub_const('CONFIG', CONFIG.merge('proxy_auth_mode' => :on))
    end

    scenario 'should log in a user when the header is set' do
      page.driver.add_header('X_USERNAME', 'proxy_user')

      visit search_path
      expect(page).to have_css('#link-to-user-home', text: 'proxy_user')
    end

    scenario 'should not log in any user when no header is set' do
      visit search_path
      expect(page).to have_content('Log In')
    end

    scenario 'should create a new user account if user does not exist in OBS' do
      page.driver.add_header('X_USERNAME', 'new_user')
      page.driver.add_header('X_EMAIL', 'new_user@obs.com')
      page.driver.add_header('X_FIRSTNAME', 'Bob')
      page.driver.add_header('X_LASTNAME', 'Geldof')

      visit search_path

      expect(page).to have_css('#link-to-user-home', text: 'new_user')
      user = User.where(login: 'new_user', realname: 'Bob Geldof', email: 'new_user@obs.com')
      expect(user).to exist
    end
  end

  scenario 'login with home project shows a link to it' do
    login user
    expect(page).to have_content "#{user.login} | Home Project | Logout"
  end

  scenario 'login without home project shows a link to create it' do
    user.home_project.destroy
    login user
    expect(page).to have_content "#{user.login} | Create Home | Logout"
  end

  scenario 'login via login page' do
    visit user_login_path
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

  context 'in kerberos mode' do
    before do
      stub_const('CONFIG', CONFIG.merge('kerberos_service_principal' => 'HTTP/obs.test.com@test_realm.com',
                                        'kerberos_realm'             => 'test_realm.com',
                                        'kerberos_mode'              => true))
    end

    context 'for a request that requires authentication' do
      before do
        visit root_path
        click_link('Log In')
      end

      context "and 'Negotiate' header is not set" do
        it 'informs the client tool (browser) that kerberos authentication is required' do
          expect(page.response_headers['WWW-Authenticate']).to eq('Negotiate')
          expect(page.status_code).to eq(401)
        end

        it 'informs users about failed kerberos authentication and possible cause' do
          expect(page).to have_text('Kerberos authentication required')
          expect(page).to have_text('You are seeing this page, because you are ' +
                                    "not authenticated in the kerberos realm ('test_realm.com').")
        end
      end
    end

    context 'for a request with valid kerberos ticket' do
      include_context 'a kerberos mock for' do
        let(:login) { user.login }
      end

      it 'authenticates the user' do
        visit project_list_path

        # In real life done by the browser / client
        page.driver.add_header('AUTHORIZATION', "Negotiate #{Base64.strict_encode64(ticket)}")

        click_link('Log In')
        expect(page).to have_content "#{login} | Home Project | Logout"
      end
    end

    context 'for a request where GSSAPI raises an exception' do
      let(:gssapi_mock) { double(:gssapi) }

      before do
        allow(gssapi_mock).to receive(:acquire_credentials).
          and_raise(GSSAPI::GssApiError, "couldn't validate ticket")

        allow(GSSAPI::Simple).to receive(:new).with(
          'obs.test.com', 'HTTP', '/etc/krb5.keytab'
        ).and_return(gssapi_mock)
      end

      it 'does not authenticate the user' do
        visit project_list_path

        page.driver.add_header('AUTHORIZATION', "Negotiate #{Base64.strict_encode64('ticket')}")

        click_link('Log In')
        expect(page).not_to have_content '| Home Project | Logout'
        expect(find('.flash-content')).to have_text "Authentication failed: 'Received a GSSAPI exception"
        expect(find('.flash-content')).to have_text "couldn't validate ticket"
      end
    end
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
      visit user_login_path
      fill_in 'Username', with: 'tux'
      fill_in 'Password', with: 'tux_password'
      click_button('Log In')

      expect(find('#link-to-user-home').text).to eq 'tux'
      expect(page).to have_content('Logout')
    end
  end
end
