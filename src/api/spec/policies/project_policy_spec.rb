require 'rails_helper'

RSpec.describe ProjectPolicy do
  let(:anonymous_user) { create(:user_nobody) }
  let(:user) { create(:confirmed_user) }
  let(:other_user) { create(:confirmed_user) }
  let(:admin_user) { create(:admin_user) }
  let(:project) { user.home_project }
  subject { ProjectPolicy }

  permissions :create?, :can_create_package_in?, :unlock?, :local_project_and_allowed_to_create_package_in? do
    it { expect(subject).to permit(user, project) }
    it { expect(subject).not_to permit(anonymous_user, project) }
    it { expect(subject).not_to permit(other_user, project) }
    it { expect(subject).to permit(admin_user, project) }
  end

  permissions :local_project_and_allowed_to_create_package_in? do
    it { expect(subject).not_to permit(user, '') }
  end
end
