require 'browser_helper'

RSpec.describe "User's admin edit page", js: true do
  let(:user) { create(:confirmed_user, realname: 'John Doe', email: 'john@suse.de') }
  let(:admin) { create(:admin_user) }
  let(:admin_role_html_id) { "user_role_ids_#{Role.find_by(title: 'Admin').id}" }

  it 'view user' do
    login(admin)
    visit edit_user_path(login: user.login)

    expect(page).to have_field('Name:', with: 'John Doe')
    expect(page).to have_field('Email:', with: 'john@suse.de')

    expect(find_field('confirmed', visible: false)).to be_checked

    ['Admin', 'unconfirmed', 'deleted', 'locked'].each do |field|
      expect(find_field(field, visible: false)).not_to be_checked
    end
  end

  it 'make user admin' do
    login(admin)
    visit edit_user_path(login: user.login)

    check('Admin')
    click_button('Update')
    expect(user.is_admin?).to be(true)
  end

  it 'remove admin rights from user' do
    login(admin)
    visit edit_user_path(login: admin.login)
    uncheck('Admin')
    click_button('Update')
    expect(admin.is_admin?).to be(false)
  end
end
