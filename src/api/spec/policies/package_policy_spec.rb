require 'rails_helper'

RSpec.describe PackagePolicy do
  let(:anonymous_user) { create(:user_nobody) }
  let(:user) { create(:confirmed_user, :with_home) }
  let(:other_user) { create(:confirmed_user) }
  let(:admin_user) { create(:admin_user) }
  let(:project) { user.home_project }
  let(:package) { create(:package, name: 'my_package', project: project) }

  subject { PackagePolicy }

  context :create_in_locked_project_without_ignore_lock do
    permissions :create? do
      before do
        allow(package.project).to receive(:is_locked?).and_return(true)
        allow(other_user).to receive(:has_global_permission?).with('create_package').and_return(true)
        allow(user).to receive(:has_local_permission?).with('create_package', package.project).and_return(true)
      end

      it { is_expected.not_to permit(user, package) }
      it { is_expected.not_to permit(other_user, package) }
      it { is_expected.not_to permit(admin_user, package) }
      it { is_expected.not_to permit(anonymous_user, package) }
    end
  end

  context :create_in_locked_project_with_ignore_lock do
    permissions :create? do
      before do
        allow(package.project).to receive(:is_locked?).and_return(true)
        allow(other_user).to receive(:has_global_permission?).with('create_package').and_return(true)
        allow(user).to receive(:has_local_permission?).with('create_package', package.project).and_return(true)
      end

      # We cannot use the `permit` matcher due to the extra argument in `new`
      it { expect(PackagePolicy.new(admin_user, package, true).create?).to be true }
      it { expect(PackagePolicy.new(other_user, package, true).create?).to be true }
      it { expect(PackagePolicy.new(user, package, true).create?).to be true }
      it { expect(PackagePolicy.new(anonymous_user, package, true).create?).to be false }
    end
  end

  context :create_in_unlocked_project do
    permissions :create? do
      before do
        allow(other_user).to receive(:has_global_permission?).with('create_package').and_return(true)
        allow(user).to receive(:has_local_permission?).with('create_package', package.project).and_return(true)
      end

      it { is_expected.to permit(admin_user, package) }
      it { is_expected.to permit(other_user, package) }
      it { is_expected.to permit(user, package) }
      it { is_expected.not_to permit(anonymous_user, package) }
    end
  end

  context :branch_as_anonymous do
    permissions :create_branch? do
      before do
        skip('it should fail but its passing')
      end

      it { expect(subject).not_to permit(anonymous_user, package) }
    end
  end

  context :branch_as_other_user do
    permissions :create_branch? do
      it { expect(subject).to permit(other_user, package) }
    end
  end

  permissions :update?, :destroy? do
    it { expect(subject).not_to permit(anonymous_user, package) }
    it { expect(subject).not_to permit(other_user, package) }

    it { expect(subject).to permit(admin_user, package) }
    it { expect(subject).to permit(user, package) }
  end

  context :source_access_enabled do
    permissions :source_access? do
      before do
        allow_any_instance_of(Package).to receive(:disabled_for?).with('sourceaccess', nil, nil).and_return(true)
      end

      it { expect(subject).to permit(user, package) }
    end
  end

  context :source_access_disabled do
    permissions :source_access? do
      before do
        allow_any_instance_of(Package).to receive(:disabled_for?).with('sourceaccess', nil, nil).and_return(false)
      end

      it { expect(subject).not_to permit(user, package) }
    end
  end
end
