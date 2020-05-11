require 'rails_helper'
require 'ostruct'

RSpec.describe ::WebuiControllerService::UserChecker do
  let(:user) { create(:confirmed_user, login: 'foo') }
  let(:user_checker) { described_class.new(http_request: request, config: config) }

  describe '#proxy_enabled?' do
    let(:user_login) { user.login }
    let(:request) { OpenStruct.new(env: { 'HTTP_X_USERNAME' => user_login }) }
    subject { user_checker.proxy_enabled? }

    context 'when its enabled' do
      let(:config) { { 'proxy_auth_mode' => :on } }
      it { expect(subject).to be(true) }
    end

    context 'when its disabled' do
      let(:config) { { 'proxy_auth_mode' => :off } }
      it { expect(subject).to be(false) }
    end
  end

  describe '#login_exists?' do
    let(:request) { OpenStruct.new(env: { 'HTTP_X_USERNAME' => user_login }) }
    let(:config) { { 'proxy_auth_mode' => :on } }
    subject { user_checker.login_exists? }

    context 'user exists' do
      let(:user_login) { user.login }
      it { expect(subject).to be(true) }
    end

    context 'user does not exist' do
      let(:user_login) { 'bar' }
      it { expect(subject).to be(false) }
    end
  end

  describe '#find_or_create_user!' do
    let(:request) do
      OpenStruct.new(env: { 'HTTP_X_USERNAME' => user_login,
                            'HTTP_X_FIRSTNAME' => 'foo', 'HTTP_X_LASTNAME' => 'bar',
                            'HTTP_X_EMAIL' => 'foo@example.org' })
    end
    let(:config) { { 'proxy_auth_mode' => :on } }
    subject { user_checker.find_or_create_user! }

    context 'it will find an user' do
      let(:user_login) { user.login }
      it { expect(subject).to eq(user) }
    end

    context 'it will create an user' do
      let(:user_login) { 'bar' }
      it { expect { subject }.to change(User, :count).by(1) }
    end
  end
end
