require 'rails_helper'

RSpec.describe RoutesHelper::RoleMatcher do
  describe '.matches?' do
    subject { described_class.matches?(request) }

    context 'when the request is from a bot' do
      let(:request) { instance_double(ActionDispatch::Request, bot?: true) }

      it { is_expected.to eq(false) }
    end

    context 'when the request is from a user with a disabled account' do
      let(:request) { instance_double(ActionDispatch::Request, bot?: false) }
      let(:user_checker) { instance_double(WebuiControllerService::UserChecker, call: false) }

      before do
        allow(WebuiControllerService::UserChecker).to receive(:new).and_return(user_checker)
      end

      it { is_expected.to eq(false) }
    end

    context 'when the request is from an anonymous user' do
      let(:request) { instance_double(ActionDispatch::Request, bot?: false, session: session) }
      let(:session) { instance_double(ActionDispatch::Request::Session) }
      let(:user_checker) { instance_double(WebuiControllerService::UserChecker, call: true) }

      before do
        allow(WebuiControllerService::UserChecker).to receive(:new).and_return(user_checker)
        allow(session).to receive(:[]).with(:login).and_return(nil)
      end

      it { is_expected.to eq(false) }
    end

    context 'when the request is from a user without any role' do
      let(:request) { instance_double(ActionDispatch::Request, bot?: false, session: session) }
      let(:session) { instance_double(ActionDispatch::Request::Session) }
      let(:user_checker) { instance_double(WebuiControllerService::UserChecker, call: true) }
      let(:user) { create(:confirmed_user) }

      before do
        allow(WebuiControllerService::UserChecker).to receive(:new).and_return(user_checker)
        allow(session).to receive(:[]).with(:login).and_return(user.login)
      end

      it { is_expected.to eq(false) }
    end

    context 'when the request is from a staff user' do
      let(:request) { instance_double(ActionDispatch::Request, bot?: false, session: session) }
      let(:session) { instance_double(ActionDispatch::Request::Session) }
      let(:user_checker) { instance_double(WebuiControllerService::UserChecker, call: true) }
      let(:user) { create(:staff_user) }

      before do
        allow(WebuiControllerService::UserChecker).to receive(:new).and_return(user_checker)
        allow(session).to receive(:[]).with(:login).and_return(user.login)
      end

      it { is_expected.to eq(true) }
    end

    context 'when the request is from an admin user' do
      let(:request) { instance_double(ActionDispatch::Request, bot?: false, session: session) }
      let(:session) { instance_double(ActionDispatch::Request::Session) }
      let(:user_checker) { instance_double(WebuiControllerService::UserChecker, call: true) }
      let(:user) { create(:admin_user) }

      before do
        allow(WebuiControllerService::UserChecker).to receive(:new).and_return(user_checker)
        allow(session).to receive(:[]).with(:login).and_return(user.login)
      end

      it { is_expected.to eq(true) }
    end
  end
end
