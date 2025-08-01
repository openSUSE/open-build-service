RSpec.describe RoutesHelper::RoleMatcher do
  describe '.matches?' do
    subject { described_class.matches?(request) }

    let(:request) { instance_double(ActionDispatch::Request, bot?: true, session: { login: user_login }, env: {}) }

    context 'when the request has no session' do
      let(:user_login) { nil }

      it { is_expected.to be(false) }
    end

    context 'when the request is from a user without any role' do
      let(:user_login) { create(:confirmed_user).login }

      it { is_expected.to be(false) }
    end

    context 'when the request is from a staff user' do
      let(:user_login) { create(:staff_user).login }

      it { is_expected.to be(true) }
    end

    context 'when the request is from an admin user' do
      let(:user_login) { create(:admin_user).login }

      it { is_expected.to be(true) }
    end
  end
end
