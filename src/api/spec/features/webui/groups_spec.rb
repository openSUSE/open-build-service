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
    expect(page).to have_link('Update group members')

    visit groups_path
    expect(page).to have_content('Showing 1 to 2 of 2 entries')
    within :xpath, "//tr[@id='group-test_group']" do
      click_link(admin.login)
    end
    expect(current_path).to eq(user_show_path(admin))
  end

  scenario 'edit group' do
    login admin
    visit groups_path

    within :xpath, "//tr[@id='group-test_group_b']" do
      click_link 'Edit Group'
    end

    expect(page).to have_content('Edit Group test_group_b')
    page.find('input#members', visible: false).set 'eisendieter'
    click_button 'Save'

    within 'form', text: 'Members:' do
      expect(page).to have_content('eisendieter')
    end
  end
end
