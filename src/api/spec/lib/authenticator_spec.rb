RSpec.describe Authenticator do
  describe '#extract_user' do
    let(:session_mock) { double(:session) }
    let(:response_mock) { double(:response, headers: {}) }

    before do
      allow(session_mock).to receive(:[]).with(:login)
      freeze_time
    end

    after do
      unfreeze_time
    end

    context 'in proxy mode' do
      before do
        allow(Configuration).to receive(:proxy_auth_mode_enabled?).and_return(true)
      end

      it_behaves_like 'a confirmed user logs in' do
        let(:request_mock) { double(:request, env: { 'HTTP_X_USERNAME' => user.login }) }
      end

      context 'and registration is disabled' do
        before do
          allow(Configuration).to receive(:registration).and_return('deny')
        end

        context 'and the user already registered to OBS' do
          it_behaves_like 'a confirmed user logs in' do
            let(:request_mock) { double(:request, env: { 'HTTP_X_USERNAME' => user.login }) }
          end
        end

        context 'and the user is not registered to OBS' do
          subject { Authenticator.new(request_mock, session_mock, response_mock) }

          let(:request_mock) { double(:request, env: { 'HTTP_X_USERNAME' => 'new_user' }) }

          it { expect { subject.extract_user }.to raise_error(Authenticator::AuthenticationRequiredError, "User 'new_user' does not exist") }
        end
      end
    end

    context 'in basic authentication mode' do
      it_behaves_like 'a confirmed user logs in' do
        let(:request_mock) { double(:request, env: { 'Authorization' => "Basic #{Base64.encode64("#{user.login}:buildservice")}" }) }
      end
    end
  end
end
