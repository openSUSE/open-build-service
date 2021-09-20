require 'rails_helper'
require 'ostruct'

RSpec.describe ::WebuiControllerService::UserChecker do
  let(:user_checker) { described_class.new(http_request: request, config: config) }

  describe '#call' do
    subject { user_checker.call }

    context 'when the proxy authentication is disabled' do
      let(:request) do
        OpenStruct.new(env: { 'HTTP_X_USERNAME' => 'something',
                              'HTTP_X_FIRSTNAME' => 'foo', 'HTTP_X_LASTNAME' => 'bar',
                              'HTTP_X_EMAIL' => 'foo@example.org' })
      end
      let(:config) { { 'proxy_auth_mode' => :off } }

      before do
        allow(User).to receive(:find_nobody!)
      end

      it { is_expected.to be(true) }

      it 'does not set the current user' do
        subject
        expect(User).not_to have_received(:find_nobody!)
      end
    end

    context 'when the proxy authentication is enabled' do
      let(:config) { { 'proxy_auth_mode' => :on } }

      context 'without a username in the request' do
        let(:request) do
          OpenStruct.new(env: { 'HTTP_X_FIRSTNAME' => 'foo', 'HTTP_X_LASTNAME' => 'bar',
                                'HTTP_X_EMAIL' => 'foo@example.org' })
        end

        before do
          allow(User).to receive(:find_nobody!)
        end

        it { is_expected.to be(true) }

        it 'sets the current user to the anonymous user' do
          subject
          expect(User).to have_received(:find_nobody!)
        end
      end

      context 'with the username of a nonexistent user in the request' do
        let(:request) do
          OpenStruct.new(env: { 'HTTP_X_USERNAME' => 'foo',
                                'HTTP_X_FIRSTNAME' => 'foo', 'HTTP_X_LASTNAME' => 'bar',
                                'HTTP_X_EMAIL' => 'foo@example.org' },
                         session: {})
        end

        it { is_expected.to be(true) }

        it 'creates a user' do
          expect { subject }.to change(User, :count).by(1)
        end
      end

      context 'with the username of an active user in the request' do
        let(:user) { create(:confirmed_user, login: 'foo') }
        let(:request) do
          OpenStruct.new(env: { 'HTTP_X_USERNAME' => user.login,
                                'HTTP_X_FIRSTNAME' => 'foo', 'HTTP_X_LASTNAME' => 'bar',
                                'HTTP_X_EMAIL' => 'foo@example.org' })
        end

        let!(:user_previous_email) { user.email }
        let!(:user_previous_realname) { user.realname }

        it { is_expected.to be(true) }

        it 'sets the current user to the user matching the request and also updates their email and realname' do
          subject
          expect(User.session!).to have_attributes(id: user.id, email: 'foo@example.org', realname: 'foo bar')
        end
      end

      context 'with the username of an inactive user in the request' do
        let(:user) { create(:user, login: 'foo') }
        let(:request) do
          OpenStruct.new(env: { 'HTTP_X_USERNAME' => user.login,
                                'HTTP_X_FIRSTNAME' => 'foo', 'HTTP_X_LASTNAME' => 'bar',
                                'HTTP_X_EMAIL' => 'foo@example.org' },
                         session: {})
        end

        it { is_expected.to be(false) }

        it 'increases the number of login failures by one' do
          expect { subject }.to change { user.reload.login_failure_count }.by(1)
        end

        it 'sets login to nil in the session' do
          subject
          expect(request.session).to eq({ login: nil })
        end
      end
    end
  end
end
