RSpec.describe UserPolicy do
  subject { described_class }

  let(:admin) { create(:admin_user) }
  let(:staff) { create(:staff_user) }
  let(:moderator) { create(:moderator) }
  let(:user) { create(:confirmed_user) }
  let(:other_user) { create(:confirmed_user) }

  permissions :update?, :destroy? do
    it { is_expected.not_to permit(user, other_user) }
    it { is_expected.to permit(admin, user) }
    it { is_expected.to permit(user, user) }
  end

  permissions :comment_index? do
    it { is_expected.not_to permit(user, other_user) }
    it { is_expected.to permit(admin, user) }
    it { is_expected.to permit(staff, user) }
    it { is_expected.to permit(moderator, user) }
    it { is_expected.to permit(user, user) }
  end

  permissions :censor? do
    it { is_expected.not_to permit(user, other_user) }
    it { is_expected.to permit(admin, user) }
    it { is_expected.to permit(moderator, user) }
  end
end
