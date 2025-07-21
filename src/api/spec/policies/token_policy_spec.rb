RSpec.describe TokenPolicy, type: :policy do
  subject { described_class }

  let(:admin_user) { create(:admin_user) }
  let(:token_user) { create(:confirmed_user) }
  let(:user_token) { create(:rebuild_token, executor: token_user) }
  let(:group) { create(:group_with_user) }
  let(:other_user) { group.users.first }
  let(:unconfirmed_user) { create(:user, state: 'unconfirmed') }
  let(:token_of_unconfirmed_user) { create(:rebuild_token, executor: unconfirmed_user) }

  # Create and update are permitted when the user and the executor are the same
  permissions :create?, :update?, :destroy? do
    it { is_expected.to permit(token_user, user_token) }
    it { is_expected.to permit(admin_user, user_token) }
    it { is_expected.not_to permit(other_user, user_token) }
  end
end
