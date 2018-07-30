require 'rails_helper'
require 'gssapi'

RSpec.describe Webui::SessionController do
  let(:user) { create(:confirmed_user, login: 'tom') }

  shared_examples 'login' do
    before do
      request.env['HTTP_REFERER'] = search_url # Needed for the redirect_to(root_url)
    end

    it 'logs in users with correct credentials' do
      post :create, params: { username: user.login, password: 'buildservice' }
      expect(response).to redirect_to search_url
    end

    it 'tells users about wrong credentials' do
      post :create, params: { username: user.login, password: 'password123' }
      expect(response).to redirect_to session_new_path
      expect(flash[:error]).to eq('Authentication failed')
    end

    it 'tells users about wrong state' do
      user.update(state: :locked)
      post :create, params: { username: user.login, password: 'buildservice' }
      expect(response).to redirect_to root_path
      expect(flash[:error]).to eq('Your account is disabled. Please contact the administrator for details.')
    end

    it 'assigns the current user' do
      post :create, params: { username: user.login, password: 'buildservice' }
      expect(User.current).to eq(user)
      expect(session[:login]).to eq(user.login)
    end
  end

  describe 'POST #create' do
    context 'without referrer' do
      before do
        post :create, params: { username: user.login, password: 'buildservice' }
      end

      it 'redirects to root path' do
        expect(response).to redirect_to root_path
      end
    end

    context 'with deprecated password' do
      let(:user) { create(:user_deprecated_password, state: :confirmed) }

      it_behaves_like 'login'
    end

    context 'with bcrypt password' do
      it_behaves_like 'login'
    end
  end

  context 'in kerberos mode' do
    before do
      stub_const('CONFIG', CONFIG.merge('kerberos_service_principal' => 'HTTP/obs.test.com@test_realm.com',
                                        'kerberos_realm'             => 'test_realm.com',
                                        'kerberos_mode'              => true))
    end

    context 'for a request that requires authentication' do
      render_views
      before do
        get :new
      end

      context "and 'Negotiate' header is not set" do
        it 'informs the client tool (browser) that kerberos authentication is required' do
          expect(response.headers['WWW-Authenticate']).to eq('Negotiate')
          expect(response.status).to eq(401)
        end

        it 'informs users about failed kerberos authentication and possible cause' do
          expect(response.body).to have_text('Kerberos authentication required')
          expect(response.body).to have_text('You are seeing this page, because you are ' \
                                    "not authenticated in the kerberos realm ('test_realm.com').")
        end
      end
    end

    context 'for a request with valid kerberos ticket' do
      include_context 'a kerberos mock for' do
        let(:login) { user.login }
        let(:ticket) { 'krb5_ticket' }
      end

      render_views
      it 'authenticates the user' do
        # In real life done by the browser / client
        request.headers['AUTHORIZATION'] = "Negotiate #{Base64.strict_encode64(ticket)}"

        get :new
        expect(response).to redirect_to root_path
        expect(User.current).to eq(user)
        expect(session[:login]).to eq(user.login)
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
        request.headers['AUTHORIZATION'] = "Negotiate #{Base64.strict_encode64('ticket')}"

        get :new
        expect(response).to redirect_to root_path
        expect(flash[:error]).to eq("Authentication failed: 'Received a GSSAPI exception; couldn't validate ticket: couldn't validate ticket.'")
      end
    end
  end

  context 'In proxy mode' do
    let!(:user) { create(:confirmed_user, login: 'proxy_user') }
    let(:username) { 'new_user' }

    before do
      # Fake proxy mode
      stub_const('CONFIG', CONFIG.merge('proxy_auth_mode' => :on))
    end

    it 'logs in a user when the header is set' do
      request.headers['HTTP_X_USERNAME'] = user.login

      # a rather unusual place to go, but this isn't really
      # about the session controller but about basic proxy mode
      get :new
      expect(User.current).to eq(user)
    end

    it 'does not log in any user when no header is set' do
      get :new
      expect(User.current.login).to eq('_nobody_')
    end

    it 'creates a new user account if user does not exist in OBS' do
      request.headers['HTTP_X_USERNAME'] = username
      request.headers['HTTP_X_EMAIL'] = 'new_user@obs.com'
      request.headers['HTTP_X_FIRSTNAME'] = 'Bob'
      request.headers['HTTP_X_LASTNAME'] = 'Geldof'

      get :new
      user = User.where(login: username, realname: 'Bob Geldof', email: 'new_user@obs.com')
      expect(user).to exist

      expect(User.current.login).to eq(user.first.login)
    end
  end
end
