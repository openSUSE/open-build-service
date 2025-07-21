RSpec.describe Authenticator do
  describe '#extract_user' do
    subject { Authenticator.new(request_mock).extract_user }

    let(:user) { create(:confirmed_user, last_logged_in_at: Time.zone.yesterday) }

    before do
      freeze_time
    end

    after do
      unfreeze_time
    end

    context 'in proxy mode' do
      let(:request_mock) { double(:request_user, env: { 'HTTP_X_USERNAME' => user.login }) }

      before do
        allow(Configuration).to receive(:proxy_auth_mode_enabled?).and_return(true)
      end

      it { expect(subject).to eq(user) }

      context 'and registration is enabled' do
        it { expect(subject).to eq(user) }
        it { expect(subject.last_logged_in_at).to eq(Time.zone.today) }
      end

      context 'and registration is disabled' do
        before do
          allow(Configuration).to receive(:registration).and_return('deny')
        end

        context 'and the user does not exist' do
          let(:request_mock) { double(:request_new_user, env: { 'HTTP_X_USERNAME' => 'new_user' }) }

          it { expect { subject }.to raise_error(Authenticator::AuthenticationRequiredError) }
        end
      end
    end

    context 'in basic auth mode' do
      let(:request_mock) { double(:request_basic_auth, session: { login: nil }, env: { Authorization: "Basic #{Base64.encode64("#{user.login}:buildservice")}" }.with_indifferent_access) }

      it { expect(subject).to eq(user) }
    end

    context 'in session authentication mode' do
      let(:request_mock) { double(:request_session, session: { login: user.login }) }

      it { expect(subject).to eq(user) }
    end
  end

  describe '#check_anonymous_access' do
    subject { Authenticator.new(request_mock).send(:check_anonymous_access, user) }

    let(:request_mock) { double(:request_somewhere, session: { login: nil }, controller_class: ApplicationController) }
    let(:user) { User.find_nobody! }

    before do
      allow(Configuration).to receive(:anonymous).and_return(false)
    end

    it { expect { subject }.to raise_error(Authenticator::AuthenticationRequiredError) }

    context 'if user is signed in' do
      let(:user) { create(:confirmed_user) }
      let(:request_mock) { double(:request_session, session: { login: user.login }, controller_class: Webui::SessionController) }

      it { expect { subject }.not_to raise_error }
    end

    context 'if user is trying to sign in' do
      let(:request_mock) { double(:request_session, session: { login: nil }, controller_class: Webui::SessionController) }

      it { expect { subject }.not_to raise_error }
    end

    context 'if user is on the frontpage' do
      let(:request_mock) { double(:request_main, session: { login: nil }, controller_class: Webui::MainController) }

      it { expect { subject }.not_to raise_error }
    end
  end

  describe '#check_user_state' do
    subject { Authenticator.new(request_mock).send(:check_user_state, user) }

    let(:request_mock) { double(:request, session: { login: user.login }) }

    context 'if user is in state unconfirmed' do
      let(:user) { create(:user) }

      it { expect { subject }.to raise_error(Authenticator::UnconfirmedUserError) }
    end

    context 'if user is inactive' do
      let(:user) { create(:locked_user) }

      it { expect { subject }.to raise_error(Authenticator::InactiveUserError) }
    end
  end
end
