RSpec.describe UserPolicy do
  subject { UserPolicy }

  let(:user) { create(:confirmed_user) }
  let(:other_user) { create(:confirmed_user) }

  before do
    User.session = user
  end

  permissions :update? do
    context 'user can modify the other user' do
      before do
        allow(user).to receive(:can_modify_user?).with(other_user).and_return true
      end

      it { expect(subject).to permit(user, other_user) }
    end

    context 'user can not modify the other user' do
      before do
        allow(user).to receive(:can_modify_user?).with(other_user).and_return false
      end

      it { expect(subject).not_to permit(user, other_user) }
    end
  end
end
