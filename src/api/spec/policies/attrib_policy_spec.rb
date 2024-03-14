RSpec.describe AttribPolicy do
  subject { described_class }

  let(:anonymous_user) { create(:user_nobody) }
  let(:user_in_a_group) { create(:groups_user, user: create(:confirmed_user, :with_home)).user }
  let(:admin_user) { create(:admin_user) }

  context 'without explicit permissions' do
    let(:attrib) { create(:attrib) }

    permissions :create?, :update?, :destroy? do
      it { is_expected.not_to permit(anonymous_user, attrib) }
      it { is_expected.not_to permit(user_in_a_group, attrib) }
      it { is_expected.to permit(admin_user, attrib) }
    end
  end

  context 'with permissions on attrib container' do
    let(:attrib) { create(:attrib, project: user_in_a_group.home_project) }

    permissions :create?, :update?, :destroy? do
      it { is_expected.not_to permit(anonymous_user, attrib) }
      it { is_expected.to permit(user_in_a_group, attrib) }
      it { is_expected.to permit(admin_user, attrib) }
    end
  end

  context 'with permissions for a group' do
    let(:attrib) { create(:attrib) }

    before do
      create(:attrib_type_modifiable_by, attrib_type: attrib.attrib_type, group: user_in_a_group.groups.first, user: nil, role: nil)
    end

    permissions :create?, :update?, :destroy? do
      it { is_expected.not_to permit(anonymous_user, attrib) }
      it { is_expected.to permit(user_in_a_group, attrib) }
      it { is_expected.to permit(admin_user, attrib) }
    end
  end

  context 'with permissions for a user' do
    let(:attrib) { create(:attrib) }

    before do
      create(:attrib_type_modifiable_by, attrib_type: attrib.attrib_type, user: user_in_a_group, group: nil, role: nil)
    end

    permissions :create?, :update?, :destroy? do
      it { is_expected.not_to permit(anonymous_user, attrib) }
      it { is_expected.to permit(user_in_a_group, attrib) }
      it { is_expected.to permit(admin_user, attrib) }
    end
  end

  context 'with permissions for a role' do
    let(:attrib) { create(:attrib, project: user_in_a_group.home_project) }
    let(:user_role) { create(:roles_user, user: user_in_a_group).role }

    before do
      create(:relationship_project_user, role: user_role, project: user_in_a_group.home_project, user: user_in_a_group)
      create(:attrib_type_modifiable_by, attrib_type: attrib.attrib_type, role: user_role, user: nil, group: nil)
    end

    permissions :create?, :update?, :destroy? do
      it { is_expected.not_to permit(anonymous_user, attrib) }
      it { is_expected.to permit(user_in_a_group, attrib) }
      it { is_expected.to permit(admin_user, attrib) }
    end
  end
end
