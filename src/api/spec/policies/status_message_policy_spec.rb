RSpec.describe StatusMessagePolicy do
  subject { described_class }

  let(:user) { create(:confirmed_user) }
  let(:staff_user) { create(:staff_user) }
  let(:admin_user) { create(:admin_user) }
  let(:status_message) { create(:status_message) }

  permissions :create?, :update?, :destroy? do
    it { is_expected.not_to permit(user, status_message) }
    it { is_expected.to permit(staff_user, status_message) }
    it { is_expected.to permit(admin_user, status_message) }
  end
end
