require "browser_helper"

RSpec.feature "User's notifications settings", type: :feature, js: true do
  let!(:user) { create(:confirmed_user, login: 'moi') }
  let!(:user_with_groups) { create(:user_with_groups, login: 'moi_wg') }

  scenario "when a user is in some group" do
    login user_with_groups
    visit user_notifications_path
    group_title = user_with_groups.groups.first.title

    expect(page).to have_content 'Get mails if in group'
    expect(page).to have_checked_field(group_title)
    uncheck group_title
    click_button 'Update'
    expect(page).to have_content 'Notifications settings updated'
    expect(page).to have_content 'Get mails if in group'
    expect(page).to have_unchecked_field(group_title)
  end

  scenario "when a user isn't in any group" do
    login user
    visit user_notifications_path

    expect(page).not_to have_content 'Get mails if in group'
  end

  scenario "when a user have some events" do
    login user
    visit user_notifications_path

    expect(page).to have_content 'Events to get email for'
    expect(page).to have_unchecked_field 'Event::RequestStatechange_creator'
    check 'Event::RequestStatechange_creator'
    check 'Event::CommentForPackage_maintainer'
    check 'Event::CommentForPackage_commenter'
    check 'Event::CommentForProject_maintainer'
    check 'Event::CommentForProject_commenter'
    click_button 'Update'

    expect(page).to have_content 'Notifications settings updated'
    expect(page).to have_content 'Events to get email for'
    expect(page).to have_checked_field 'Event::RequestStatechange_creator'
    expect(page).to have_checked_field 'Event::CommentForPackage_maintainer'
    expect(page).to have_checked_field 'Event::CommentForPackage_commenter'
    expect(page).to have_checked_field 'Event::CommentForProject_maintainer'
    expect(page).to have_checked_field 'Event::CommentForProject_commenter'
  end
end
