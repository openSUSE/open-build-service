require 'tasks/user_admin_rights'

RSpec.describe UserAdminRights do
  subject do
    UserAdminRights.new(user).toggle!
  end

  let(:user) { create(:confirmed_user) }
  let(:admin_role) { Role.global.where(title: 'Admin').first }

  context 'when user has no admin rights' do
    it 'grants the admin rights' do
      expect(subject.roles).to contain_exactly(admin_role)
    end
  end

  context 'when the user already has admin rights' do
    before do
      user.roles << admin_role
    end

    it 'removes the admin rights' do
      expect(subject.reload.roles).to be_empty
    end
  end

  context 'when there is no user' do
    let(:user) { nil }

    it 'fails with an error' do
      expect { subject.roles }.to raise_error(NotFoundError)
    end
  end
end
