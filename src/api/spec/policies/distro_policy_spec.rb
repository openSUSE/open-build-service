RSpec.describe DistroPolicy do
  subject { described_class }

  let(:anonymous_user) { User.find_nobody! }
  let(:another_user) { create(:confirmed_user) }
  let(:admin) { create(:admin_user) }
  let(:user) { create(:confirmed_user) }
  let(:project) { create(:project, maintainer: user) }
  let(:vendor) { create(:vendor, project: project) }
  let(:distro) { create(:distro, vendor: vendor) }

  permissions :create?, :new?, :update?, :destroy? do
    it { is_expected.not_to permit(anonymous_user, distro) }
    it { is_expected.not_to permit(another_user, distro) }
    it { is_expected.to permit(user, distro) }
    it { is_expected.to permit(admin, distro) }
  end
end
