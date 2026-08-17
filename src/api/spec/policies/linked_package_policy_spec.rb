RSpec.describe LinkedPackagePolicy do
  subject { described_class }

  let(:user) { create(:confirmed_user, :with_home) }
  let(:scmsync_project) { create(:project, name: 'scmsync_home', scmsync: 'https://example.com/repo.git') }
  let(:linked_package) { create(:linked_package, name: 'linked', project: scmsync_project) }

  before do
    # The user maintains the scmsync project, so permissions would pass if the package were normal.
    create(:relationship, project: scmsync_project, user: user, role: Role.find_by_title('maintainer'))
  end

  describe 'forbidden source-modifying features' do
    %i[update? save_meta_update? destroy? unlock?].each do |action|
      permissions action do
        it { is_expected.not_to permit(user, linked_package) }
      end
    end
  end

  describe 'allowed non-source features' do
    # rebuild is a build-state operation and does not modify the source, so a maintainer keeps
    # normal permissions. Frontend-only features (labels, ...) stay allowed too.
    permissions :rebuild?, :update_labels? do
      it { is_expected.to permit(user, linked_package) }
    end
  end

  it 'is resolved automatically by Pundit for a LinkedPackage record' do
    expect(Pundit.policy(user, linked_package)).to be_a(described_class)
  end
end
