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
      expect(response).to redirect_to new_session_path
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
      expect(User.session!).to eq(user)
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
                                        'kerberos_realm' => 'test_realm.com',
                                        'kerberos_mode' => true))
    end

    context 'for a request that requires authentication' do
      render_views
      before do
        get :new
      end

      context "and 'Negotiate' header is not set" do
        it 'informs the client tool (browser) that kerberos authentication is required' do
          expect(response.headers['WWW-Authenticate']).to eq('Negotiate')
          expect(response).to have_http_status(:unauthorized)
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
        expect(User.session!).to eq(user)
        expect(session[:login]).to eq(user.login)
      end
    end

    context 'for a request where GSSAPI raises an exception' do
      let(:gssapi_mock) { double(:gssapi) }

      before do
        allow(gssapi_mock).to receive(:acquire_credentials)
          .and_raise(GSSAPI::GssApiError, "couldn't validate ticket")

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
      allow(Configuration).to receive(:proxy_auth_mode_enabled?).and_return(true)
    end

    it 'does not log in any user when no header is set' do
      get :new
      expect(User.session).to be_nil
    end

    context 'when header is set' do
      before do
        request.headers['HTTP_X_USERNAME'] = user.login
        request.headers['HTTP_X_EMAIL'] = user.email
      end

      it 'logs in a user' do
        # a rather unusual place to go, but this isn't really
        # about the session controller but about basic proxy mode
        get :new
        expect(User.session!).to eq(user)
      end

      it 'updates last_logged_in_at' do
        user.update(last_logged_in_at: nil)

        get :new
        expect(user.reload.last_logged_in_at).to eq(Time.zone.today)
      end
    end

    context 'when user does not exist in OBS' do
      before do
        request.headers['HTTP_X_USERNAME'] = username
        request.headers['HTTP_X_EMAIL'] = 'new_user@obs.com'
        request.headers['HTTP_X_FIRSTNAME'] = 'Bob'
        request.headers['HTTP_X_LASTNAME'] = 'Geldof'
      end

      it 'creates a new user account' do
        get :new
        user = User.where(login: username, realname: 'Bob Geldof', email: 'new_user@obs.com')
        expect(user).to exist

        expect(User.session!.login).to eq(user.first.login)
      end

      it 'sets last_logged_in_at on creation' do
        get :new
        user = User.find_by(login: username, realname: 'Bob Geldof', email: 'new_user@obs.com')
        expect(user.last_logged_in_at).to eq(Time.zone.today)
      end
    end

    context 'when the user is not confirmed' do
      let!(:unconfirmed_user) { create(:user, login: 'unconfirmed_proxy_user') }
      let(:username) { 'unconfirmed_user' }

      before do
        request.headers['HTTP_X_USERNAME'] = unconfirmed_user.login
        request.headers['HTTP_X_EMAIL'] = unconfirmed_user.email
        stub_const('CONFIG', { proxy_auth_logout_page: '/' }.with_indifferent_access)
      end

      it 'tracks a failure and send message to RabbitMQ', rabbitmq: '#' do
        expect(unconfirmed_user.reload.login_failure_count).to eq(0)
        get :new
        expect(unconfirmed_user.reload.login_failure_count).to eq(1)
        expect(User.session).to be_nil
        expect_message('opensuse.obs.metrics', 'user.create value=1')
      end
    end
  end
end
