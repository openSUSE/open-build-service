require 'rails_helper'

RSpec.describe PackagePolicy do
  let(:anonymous_user) { create(:user_nobody) }
  let(:user) { create(:confirmed_user) }
  let(:other_user) { create(:confirmed_user) }
  let(:admin_user) { create(:admin_user) }
  let(:project) { user.home_project }
  let(:package) { create(:package, name: 'my_package', project: project) }

  subject { PackagePolicy }

  context :branch_as_anonymous do
    permissions :branch? do
      before do
        skip('it should fail but its passing')
      end

      it { expect(subject).not_to permit(anonymous_user, package) }
    end
  end

  context :branch_as_other_user do
    permissions :branch? do
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
