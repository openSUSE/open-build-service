require 'browser_helper'

RSpec.feature "User's notifications settings", type: :feature, js: true do
  let(:user_with_groups) { create(:user_with_groups, login: 'moi_wg') }

  before do
    skip_if_bootstrap
  end

  scenario 'when a user is in some group' do
    login user_with_groups
    visit user_notifications_path
    group_title = user_with_groups.groups.first.title

    expect(page).to have_content 'You will receive emails from the checked groups'
    # Using `visible: :all` for the Bootstrap version (as the checkboxes aren't found otherwise)
    expect(page).to have_checked_field(group_title, visible: :all)
    uncheck(group_title, allow_label_click: true)
    click_button 'Update'
    expect(page).to have_content 'Notifications settings updated'
    expect(page).to have_content 'You will receive emails from the checked groups'
    # Using `visible: :all` for the Bootstrap version (as the checkboxes aren't found otherwise)
    expect(page).to have_unchecked_field(group_title, visible: :all)
  end
end
