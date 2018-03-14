require 'browser_helper'

RSpec.feature "User's admin edit page", type: :feature, js: true do
  let(:user) { create(:confirmed_user, realname: 'John Doe', email: 'john@suse.de') }
  let(:admin) { create(:admin_user) }

  scenario 'view user' do
    login(admin)
    visit user_edit_path(user: user.login)

    expect(page).to have_field('Name:', with: 'John Doe')
    expect(page).to have_field('e-Mail:', with: 'john@suse.de')

    expect(find_field('Admin')).to_not be_checked
    expect(find_field('confirmed')).to be_checked
    expect(find_field('unconfirmed')).to_not be_checked
    expect(find_field('deleted')).to_not be_checked
    expect(find_field('locked')).to_not be_checked
  end

  scenario 'make user admin' do
    login(admin)
    visit user_edit_path(user: user.login)
    check('Admin')
    click_button('Update')
    expect(user.is_admin?).to be true
  end

  scenario 'remove admin rights from user' do
    login(admin)
    visit user_edit_path(user: admin.login)
    uncheck('Admin')
    click_button('Update')
    expect(admin.is_admin?).to be false
  end
end
