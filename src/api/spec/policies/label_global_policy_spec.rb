RSpec.describe LabelGlobalPolicy do
  subject { described_class }

  let(:anonymous_user) { create(:user_nobody) }
  let(:another_user) { create(:confirmed_user) }
  let(:admin) { create(:admin_user) }
  let(:user) { create(:confirmed_user) }
  let(:project) { create(:project, maintainer: user) }

  before do
    Flipper.enable(:labels)
  end

  permissions :create?, :destroy?, :update? do
    it { is_expected.not_to permit(anonymous_user, project) }
    it { is_expected.not_to permit(another_user, project) }
    it { is_expected.to permit(user, project) }
    it { is_expected.to permit(admin, project) }
  end
end
