RSpec.describe Cloud::Azure::ConfigurationPolicy do
  subject { described_class }

  let(:user) { create(:user) }
  let(:other_user) { build(:user) }
  let(:user_nobody) { build(:user_nobody) }
  let(:azure_configuration) { create(:azure_configuration, :skip_encrypt_credentials, user: user) }

  permissions :show?, :update?, :destroy? do
    it { is_expected.to permit(user, azure_configuration) }
    it { is_expected.not_to permit(other_user, azure_configuration) }
  end
end
