RSpec.describe GroupsUser do
  let(:group) { create(:group) }
  let(:user) { create(:confirmed_user, login: 'eisendieter') }

  it 'creates an AddedToGroupEvent when a user is added to a group' do
    allow(Event::AddedUserToGroup).to receive(:create)

    group.add_user(user)

    expect(Event::AddedUserToGroup).to have_received(:create).with(group: group, user: user)
  end

  it 'creates a RemovedFromGroupEvent when a user is removed from a group' do
    allow(Event::RemovedUserFromGroup).to receive(:create)

    group.add_user(user)

    group.remove_user(user)
    expect(Event::RemovedUserFromGroup).to have_received(:create).with(group: group, user: user)
  end
end
