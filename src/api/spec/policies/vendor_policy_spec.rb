RSpec.describe VendorPolicy do
  subject { described_class }

  let(:anonymous_user) { User.find_nobody! }
  let(:another_user) { create(:confirmed_user) }
  let(:admin) { create(:admin_user) }
  let(:user) { create(:confirmed_user) }
  let(:project) { create(:project, maintainer: user) }
  let(:vendor) { create(:vendor, project: project) }

  permissions :show? do
    it { is_expected.to permit(anonymous_user, vendor) }
    it { is_expected.to permit(another_user, vendor) }
  end

  permissions :create?, :new?, :update?, :destroy? do
    it { is_expected.not_to permit(anonymous_user, vendor) }
    it { is_expected.not_to permit(another_user, vendor) }
    it { is_expected.to permit(user, vendor) }
    it { is_expected.to permit(admin, vendor) }
  end
end
