require 'browser_helper'

RSpec.describe "User's admin edit page", :js, :vcr do
  let(:user) { create(:confirmed_user, realname: 'John Doe', email: 'john@suse.de') }
  let(:admin) { create(:admin_user) }

  before do
    login(admin)
  end

  it 'view user' do
    visit edit_user_path(login: user.login)

    expect(page).to have_field('Name:', with: 'John Doe')
    expect(page).to have_field('Email:', with: 'john@suse.de')

    expect(find_field('confirmed', visible: false)).to be_checked

    %w[Admin unconfirmed deleted locked].each do |field|
      expect(find_field(field, visible: false)).not_to be_checked
    end
  end

  it 'make user admin' do
    visit edit_user_path(login: user.login)
    check('Admin')
    click_button('Update')

    expect(page).to have_content('successfully updated')
    expect(user).to be_admin
  end

  it 'remove admin rights from user' do
    visit edit_user_path(login: admin.login)
    uncheck('Admin')
    click_button('Update')

    expect(page).to have_content('Requires admin privileges')
    expect(admin).not_to be_admin
  end
end
