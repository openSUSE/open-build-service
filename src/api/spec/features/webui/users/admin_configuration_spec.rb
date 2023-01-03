require 'browser_helper'

RSpec.describe 'Admin user configuration page', js: true do
  let!(:user) { create(:confirmed_user, realname: 'John Doe', email: 'john@suse.de') }
  let!(:users) { create_list(:confirmed_user, 3) }
  let(:admin) { create(:admin_user) }
  let(:admin_role_html_id) { "user_role_ids_#{Role.find_by(title: 'Admin').id}" }

  before do
    login(admin)
    visit users_path
  end

  it 'view users' do
    expect(find_all('tbody tr').count).to eq(5)
    expect(find_all('td', text: 'confirmed').count).to eq(5)
    # The actions column
    within(find('td', text: /#{user.realname}/).ancestor('tr')) do
      expect(page).to have_css("a[href='#{edit_user_path(user)}']")
      expect(page).to have_css("a[href='mailto:#{user.email}']")
      expect(page).to have_css("a[href='#{user_path(user.login)}']")
    end
  end

  it 'delete user' do
    within(find('td', text: /#{user.realname}/).ancestor('tr')) do
      expect(page).to have_css('td', text: 'confirmed')
      page.find('a[title="Delete User"]').click
    end
    # Accept the confirmation dialog
    click_button('Delete')
    expect(page).to have_css('td', text: 'deleted')
  end

  it 'create user' do
    expect(page).to have_text('5 records')
    click_link('Create User')

    fill_in 'Username:', with: 'tux'
    fill_in 'Email', with: 'tux@suse.de'
    fill_in 'Enter a password', with: 'test123'
    fill_in 'Password confirmation', with: 'test123'
    click_button('Create')

    expect(page).to have_text("The account 'tux' is now active.")
    expect(page).to have_current_path(users_path)
    expect(page).to have_css('td', text: 'tux')
  end
end
