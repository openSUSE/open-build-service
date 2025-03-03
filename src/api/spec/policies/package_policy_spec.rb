RSpec.describe PackagePolicy do
  subject { described_class }

  let(:anonymous_user) { create(:user_nobody) }
  let(:user) { create(:confirmed_user, :with_home) }
  let(:other_user) { create(:confirmed_user) }
  let(:admin_user) { create(:admin_user) }
  let(:project) { user.home_project }
  let(:package) { create(:package, name: 'my_package', project: project) }

  context 'create in locked project without ignore lock' do
    permissions :create? do
      before do
        allow(package.project).to receive(:locked?).and_return(true)
        allow(other_user).to receive(:global_permission?).with('create_package').and_return(true)
        allow(user).to receive(:local_permission?).with('create_package', package.project).and_return(true)
      end

      it { is_expected.not_to permit(user, package) }
      it { is_expected.not_to permit(other_user, package) }
      it { is_expected.not_to permit(admin_user, package) }
      it { is_expected.not_to permit(anonymous_user, package) }
    end
  end

  context 'create in locked project with ignore lock' do
    permissions :create? do
      before do
        allow(package.project).to receive(:locked?).and_return(true)
        allow(other_user).to receive(:global_permission?).with('create_package').and_return(true)
        allow(user).to receive(:local_permission?).with('create_package', package.project).and_return(true)
      end

      # We cannot use the `permit` matcher due to the extra argument in `new`
      it { expect(PackagePolicy.new(admin_user, package, ignore_lock: true).create?).to be true }
      it { expect(PackagePolicy.new(other_user, package, ignore_lock: true).create?).to be true }
      it { expect(PackagePolicy.new(user, package, ignore_lock: true).create?).to be true }
      it { expect(PackagePolicy.new(anonymous_user, package, ignore_lock: true).create?).to be false }
    end
  end

  context 'create in unlocked project' do
    permissions :create? do
      before do
        allow(other_user).to receive(:global_permission?).with('create_package').and_return(true)
        allow(user).to receive(:local_permission?).with('create_package', package.project).and_return(true)
      end

      it { is_expected.to permit(admin_user, package) }
      it { is_expected.to permit(other_user, package) }
      it { is_expected.to permit(user, package) }
      it { is_expected.not_to permit(anonymous_user, package) }
    end
  end

  context 'branch as anonymous' do
    permissions :create_branch? do
      before do
        skip('it should fail but its passing')
      end

      it { expect(subject).not_to permit(anonymous_user, package) }
    end
  end

  context 'branch as other user' do
    permissions :create_branch? do
      it { expect(subject).to permit(other_user, package) }

      context 'source access disabled' do
        before do
          allow(package).to receive(:enabled_for?).with('sourceaccess', nil, nil).and_return(false)
        end

        it { expect(subject).not_to permit(other_user, package) }
      end
    end
  end

  permissions :update?, :destroy? do
    it { expect(subject).not_to permit(anonymous_user, package) }
    it { expect(subject).not_to permit(other_user, package) }

    it { expect(subject).to permit(admin_user, package) }
    it { expect(subject).to permit(user, package) }
  end
end
