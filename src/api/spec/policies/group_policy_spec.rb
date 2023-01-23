require 'rails_helper'

RSpec.describe GroupPolicy do
  let(:group) { create(:group) }
  let(:anonymous_user) { create(:user_nobody) }
  let(:user) { create(:confirmed_user) }
  let(:admin) { create(:admin_user) }
  let(:group_member) { create(:groups_user, group: group).user }
  let(:group_maintainer) { create(:group_maintainer, group: group).user }

  subject { GroupPolicy }

  # rubocop:disable RSpec/RepeatedExample
  # This cop is currently not recognizing the permissions block as separate test
  permissions :create?, :index? do
    it { is_expected.not_to permit(user, group) }
    it { is_expected.not_to permit(group_member, group) }
    it { is_expected.not_to permit(group_maintainer, group) }
    it { is_expected.to permit(admin, group) }
  end

  permissions :update?, :destroy? do
    it { is_expected.not_to permit(user, group) }
    it { is_expected.not_to permit(group_member, group) }
    it { is_expected.to permit(group_maintainer, group) }
    it { is_expected.to permit(admin, group) }
  end

  permissions :display_email? do
    it { is_expected.not_to permit(anonymous_user, group) }
    it { is_expected.to permit(user, group) }
    it { is_expected.to permit(group_member, group) }
    it { is_expected.to permit(group_maintainer, group) }
    it { is_expected.to permit(admin, group) }
  end
  # rubocop:enable RSpec/RepeatedExample
end
