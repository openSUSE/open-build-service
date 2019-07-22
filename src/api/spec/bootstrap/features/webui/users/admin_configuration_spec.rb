# typed: false
require 'browser_helper'

RSpec.feature 'Admin user configuration page', type: :feature, js: true do
  let!(:user) { create(:confirmed_user, realname: 'John Doe', email: 'john@suse.de') }
  let!(:users) { create_list(:confirmed_user, 3) }
  let(:admin) { create(:admin_user) }
  let(:admin_role_html_id) { "user_role_ids_#{Role.find_by(title: 'Admin').id}" }

  before do
    login(admin)
    visit users_path
  end

  scenario 'view users' do
    expect(find_all('tbody tr').count).to eq(5)
    expect(find_all('td', text: 'confirmed').count).to eq(5)
    # The actions column
    within(find('td', text: /#{user.realname}/).ancestor('tr')) do
      expect(page).to have_css("a[href='#{user_edit_path(user)}']")
      expect(page).to have_css("a[href='mailto:#{user.email}']")
      expect(page).to have_css("a[href='#{user_delete_path(user: { login: user.login })}']")
    end
  end

  scenario 'delete user' do
    within(find('td', text: /#{user.realname}/).ancestor('tr')) do
      expect(page).to have_css('td', text: 'confirmed')
      page.find('a[data-method=delete]').click
      # Accept the confirmation dialog
      page.driver.browser.switch_to.alert.accept
      expect(page).to have_css('td', text: 'deleted')
    end
  end

  scenario 'create user' do
    expect(page).to have_text('5 entries')
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
