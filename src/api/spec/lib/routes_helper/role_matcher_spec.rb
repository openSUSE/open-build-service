RSpec.describe RoutesHelper::RoleMatcher do
  describe '.matches?' do
    subject { described_class.matches?(request) }

    let(:request) { instance_double(ActionDispatch::Request, bot?: true) }

    context 'when the request is from an unconfirmed user' do
      let(:user) { create(:locked_user) }

      before do
        User.session = user
      end

      it { is_expected.to be(false) }
    end

    context 'when the request has no session' do
      it { is_expected.to be(false) }
    end

    context 'when the request is from a user without any role' do
      let(:user) { create(:confirmed_user) }

      before do
        User.session = user
      end

      it { is_expected.to be(false) }
    end

    context 'when the request is from a staff user' do
      let(:user) { create(:staff_user) }

      before do
        User.session = user
      end

      it { is_expected.to be(true) }
    end

    context 'when the request is from an admin user' do
      let(:user) { create(:admin_user) }

      before do
        User.session = user
      end

      it { is_expected.to be(true) }
    end
  end
end
