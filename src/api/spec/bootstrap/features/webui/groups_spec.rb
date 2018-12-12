require 'browser_helper'

RSpec.feature 'Groups', type: :feature, js: true do
  let(:admin) { create(:admin_user, login: 'king') }
  let(:user) { create(:confirmed_user, login: 'eisendieter') }
  let!(:group) { create(:group, title: 'test_group', users: [admin, user]) }
  let!(:another_group) { create(:group, title: 'test_group_b') }

  scenario 'visit group page' do
    login admin
    visit groups_path

    expect(page).to have_content('Showing 1 to 2 of 2 entries')
    click_link('test_group_b')
    expect(page).to have_content('Incoming Reviews')
    find('#group-members-tab').click
    expect(page).to have_content('This group does not contain users.')
    expect(page).to have_link('Add User')

    visit groups_path
    expect(page).to have_content('Showing 1 to 2 of 2 entries')
    within :xpath, "//tr[@id='group-test_group']" do
      click_link(admin.login)
    end
    expect(page).to have_current_path(user_show_path(admin))
  end

  scenario 'add a user' do
    login admin
    visit groups_path

    within :xpath, "//tr[@id='group-test_group_b']" do
      click_link 'test_group_b'
    end

    find('#group-members-tab').click
    click_link 'Add User'
    fill_in 'group_userid', with: 'eisendieter'
    click_button('Accept')
    expect(page).to have_content('eisendieter')
  end
end
