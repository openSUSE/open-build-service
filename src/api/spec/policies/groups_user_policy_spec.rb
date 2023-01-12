require 'rails_helper'

RSpec.describe GroupsUserPolicy do
  subject { described_class }

  permissions :destroy? do
    let(:group) { create(:group) }

    context 'as an admin' do
      let(:admin) { create(:admin_user) }
      let(:groups_user) { create(:groups_user, group: group) }

      it { is_expected.to permit(admin, groups_user) }
    end

    context 'as a group maintainer' do
      let(:group_maintainer) { create(:group_maintainer, group: group).user }
      let(:groups_user) { create(:groups_user, group: group) }

      it { is_expected.to permit(group_maintainer, groups_user) }
    end

    context 'as a group member' do
      let(:group_member) { create(:confirmed_user) }

      context 'when removing themselves from a group' do
        let(:groups_user) { create(:groups_user, group: group, user: group_member) }

        it { is_expected.to permit(group_member, groups_user) }
      end

      context 'when removing someone else from a group' do
        let(:groups_user) { create(:groups_user, group: group) }

        it { is_expected.not_to permit(group_member, groups_user) }
      end
    end

    context 'as a user which is not a group member' do
      let(:groups_user) { create(:groups_user, group: group) }
      let(:other_user) { create(:confirmed_user) }

      it { is_expected.not_to permit(other_user, groups_user) }
    end
  end
end
