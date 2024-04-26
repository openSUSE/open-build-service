RSpec.describe CommentLockPolicy do
  subject { described_class }

  let(:user) { create(:confirmed_user) }
  let(:report) { create(:report) }
  let(:non_maintaned_project) { create(:project) }
  let(:project) { create(:project, maintainer: user) }

  before do
    Flipper.enable(:content_moderation)
  end

  permissions :create? do
    it { is_expected.not_to permit(user, report) }
    it { is_expected.not_to permit(user, non_maintaned_project) }
    it { is_expected.to permit(user, project) }
  end
end
