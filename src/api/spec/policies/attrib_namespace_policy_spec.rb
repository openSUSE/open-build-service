RSpec.describe AttribNamespacePolicy do
  subject { described_class }

  let(:anonymous_user) { create(:user_nobody) }
  let(:user_in_a_group) { create(:groups_user, user: create(:confirmed_user)).user }
  let(:admin_user) { create(:admin_user) }
  let(:attrib_namespace) { create(:attrib_namespace) }

  context 'without explicit permissions' do
    permissions :create?, :update?, :destroy? do
      it { is_expected.not_to permit(anonymous_user, attrib_namespace) }
      it { is_expected.not_to permit(user_in_a_group, attrib_namespace) }
      it { is_expected.to permit(admin_user, attrib_namespace) }
    end
  end

  context 'with explicit permissions for a group' do
    before do
      create(:attrib_namespace_modifiable_by, attrib_namespace: attrib_namespace, group: user_in_a_group.groups.first, user: nil)
    end

    permissions :create?, :update?, :destroy? do
      it { is_expected.not_to permit(anonymous_user, attrib_namespace) }
      it { is_expected.to permit(user_in_a_group, attrib_namespace) }
      it { is_expected.to permit(admin_user, attrib_namespace) }
    end
  end

  context 'with explicit permissions for a user' do
    before do
      create(:attrib_namespace_modifiable_by, attrib_namespace: attrib_namespace, user: user_in_a_group, group: nil)
    end

    permissions :create?, :update?, :destroy? do
      it { is_expected.not_to permit(anonymous_user, attrib_namespace) }
      it { is_expected.to permit(user_in_a_group, attrib_namespace) }
      it { is_expected.to permit(admin_user, attrib_namespace) }
    end
  end
end
