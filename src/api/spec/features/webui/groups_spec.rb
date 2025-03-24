require 'browser_helper'

RSpec.describe 'Groups', :js do
  let(:admin) { create(:admin_user, login: 'king') }
  let(:user1) { create(:confirmed_user, login: 'eisendieter') }
  let!(:group1) { create(:group, title: 'test_group', users: [admin, user1]) }
  let!(:group2) { create(:group, title: 'test_group_b') }

  before do
    login admin
  end

  def group_in_datatable(page, group)
    expect(page).to have_link(group.title, href: group_path(group))
    group.users.each { |user| expect(page).to have_link(user.login, href: user_path(user)) }
  end

  it 'visit groups index page' do
    visit groups_path

    [group1, group2].each do |group|
      group_in_datatable(page, group)
    end

    expect(page).to have_content('1 of 1 (2 records)')
  end

  it 'visit group show page' do
    visit group_path(group1)

    # TODO: Remove this line if the dropdown is changed to a scrollable tab
    find('.nav-link.dropdown-toggle').click if mobile?
    expect(page).to have_content('Incoming Reviews')
    expect(page).to have_content('Incoming Requests')
    expect(page).to have_content('All Requests')
    find_by_id('group-members-tab').click

    expect(page).to have_link('Add Member')
    group1.users.each { |user| expect(page).to have_link(user.login, href: user_path(user)) }
  end

  it 'create a group' do
    visit groups_path

    click_link('Create Group')

    new_group_title = 'group_123'
    fill_in('group_title', with: new_group_title)
    # Typing a comma after a user login selects it (just like clicking on the autocomplete menu popping up). It's a built-in feature of the tokenfield
    fill_in('group-members_tag', with: "#{admin},#{user1},")

    click_button('Create')

    expect(page).to have_content("Group '#{new_group_title}' successfully created.")
    group_in_datatable(page, Group.find_by(title: new_group_title))
    expect(Group.where(title: new_group_title)).to exist
  end

  it 'remove a member from a group' do
    visit group_path(group1)

    within('#group-users > .card', text: admin.login) do
      click_link('Remove member from group')
    end
    click_button('Remove')

    expect(page).to have_content("Removed user '#{admin}' from group '#{group1}'")
    expect(group1.reload.users.pluck(:login)).to contain_exactly(user1.login)
  end

  it 'give maintainer rights to a group member' do
    visit group_path(group1)

    within('#group-users > .card', text: admin.login) do
      check('Maintainer')
    end

    expect(page).to have_content("Gave maintainer rights to '#{admin}'")
  end

  it 'add a group member' do
    visit group_path(group2)

    click_link('Add Member')
    within('#add-group-user-modal') do
      fill_in('user_login', with: admin.login)
    end
    click_button('Accept')

    expect(page).to have_content("Added user '#{admin}' to group '#{group2}'")
    expect(group2.users.pluck(:login)).to contain_exactly(admin.login)

    visit groups_path
    group_in_datatable(page, group2)
  end
end
