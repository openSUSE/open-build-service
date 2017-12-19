require 'browser_helper'

RSpec.feature "User's notifications settings", type: :feature, js: true do
  let(:user_with_groups) { create(:user_with_groups, login: 'moi_wg') }

  scenario 'when a user is in some group' do
    login user_with_groups
    visit user_notifications_path
    group_title = user_with_groups.groups.first.title

    expect(page).to have_content 'You will receive emails from the checked groups'
    expect(page).to have_checked_field(group_title)
    uncheck group_title
    click_button 'Update'
    expect(page).to have_content 'Notifications settings updated'
    expect(page).to have_content 'You will receive emails from the checked groups'
    expect(page).to have_unchecked_field(group_title)
  end
end
