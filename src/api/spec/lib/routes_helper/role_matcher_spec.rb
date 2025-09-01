RSpec.describe RoutesHelper::RoleMatcher do
  describe '.matches?' do
    subject { described_class.matches?(request) }

    let(:request) { double(session: { login: user.login }) }

    context 'when the request is from an anonymous user' do
      let(:request) { double(session: { login: nil }) }

      it { is_expected.to be(false) }
    end

    context 'when the request is from a user without any role' do
      let(:user) { create(:confirmed_user) }

      it { is_expected.to be(false) }
    end

    context 'when the request is from a user with an inactive account' do
      let(:user) { create(:locked_user) }

      it { is_expected.to be(false) }
    end

    context 'when the request is from a staff user' do
      let(:user) { create(:staff_user) }

      it { is_expected.to be(true) }
    end

    context 'when the request is from an admin user' do
      let(:user) { create(:admin_user) }

      it { is_expected.to be(true) }
    end
  end
end
