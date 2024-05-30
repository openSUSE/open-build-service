RSpec.describe GroupsUser do
  let(:group) { create(:group) }
  let(:user) { create(:confirmed_user, login: 'eisendieter') }

  it 'creates an AddedToGroupEvent when a user is added to a group' do
    expect(Event::AddedUserToGroup).to receive(:create).with(group: group, user: user)
    group.add_user(user)
  end

  it 'creates a RemovedFromGroupEvent when a user is removed from a group' do
    group.add_user(user)
    group.remove_user(user)
    expect(Event::RemovedUserFromGroup).to have_received(:create).with(group: group, user: user)
  end
end
