RSpec.describe Event::GlobalRoleAssignmentUpdate, type: :model do
  describe '#admin_moderator_or_staffs' do
    let!(:admin) { create(:admin_user) }
    let!(:staff) { create(:staff_user) }
    let!(:moderator) { create(:moderator) }
    let!(:affected_user) { create(:confirmed_user, login: 'affected_user') }
    let!(:originator) { create(:admin_user) }

    context "when the enabled role is 'Staff'" do
      let(:event) do
        described_class.new('role' => 'Staff', 'user' => affected_user.login, 'who' => originator.login, 'action' => 'enabled')
      end

      it 'notifies admins, staff, and the target user, but excludes the originator' do
        result = event.admin_moderator_or_staffs
        expect(result).to include(admin, staff, affected_user)
        expect(result).not_to include(moderator, originator)
      end
    end

    context "when the disabled role is 'Staff'" do
      let(:event) do
        described_class.new('role' => 'Staff', 'user' => affected_user.login, 'who' => originator.login, 'action' => 'disabled')
      end

      it 'notifies admins, staff, and the target user, but excludes the originator' do
        result = event.admin_moderator_or_staffs
        expect(result).to include(admin, staff, affected_user)
        expect(result).not_to include(moderator, originator)
      end
    end
  end
end
