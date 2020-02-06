require 'rails_helper'

RSpec.describe AuthenticationProtocolHelper do
  describe '#can_register?' do
    context 'current user is admin' do
      before do
        User.session = create(:admin_user)
      end

      it { expect(can_register?).to be(true) }
    end

    context 'user is not registered' do
      before do
        User.session = create(:user)
        allow(UnregisteredUser).to receive(:can_register?).and_raise(APIError)
      end

      it { expect(can_register?).to be(false) }
    end

    context 'user is registered' do
      it { expect(can_register?).to be(true) }
    end
  end
end
