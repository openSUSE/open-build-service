require 'browser_helper'

RSpec.feature "User's home project creation", type: :feature, js: true do
  let!(:user) do
    create(:confirmed_user,
           login: 'Jim',
           realname: 'Jim Knopf',
           email: 'jim.knopf@puppenkiste.com')
  end

  describe 'as an anonymous user' do
    before do
      visit user_path(user)
    end

    scenario 'view home page of another user' do
      expect(page).to have_css('#home-realname', text: 'Jim Knopf')
      expect(page).not_to have_css("a[href='mailto:jim.knopf@puppenkiste.com']", text: 'jim.knopf@puppenkiste.com')

      expect(page).not_to have_text('Edit your account')
      expect(page).not_to have_text('Change your password')

      expect(page).to have_link('Involved Packages')
      expect(page).to have_link('Involved Projects')
      expect(page).to have_link('Owned Project/Packages')
    end
  end

  describe 'as a logged-in user' do
    before do
      login user
      visit home_path
    end

    scenario 'view home page' do
      expect(page).to have_css('#home-realname', text: 'Jim Knopf')
      expect(page).to have_css("a[href='mailto:jim.knopf@puppenkiste.com']", text: 'jim.knopf@puppenkiste.com')

      expect(page).to have_text('Edit your account')
      expect(page).to have_text('Change your password')

      expect(page).to have_link('Involved Packages')
      expect(page).to have_link('Involved Projects')
      expect(page).to have_link('Owned Project/Packages')
    end

    scenario 'view tasks page' do
      visit user_tasks_path(user)

      expect(page).to have_link('Incoming Requests')
      expect(page).to have_link('Outgoing Requests')
      expect(page).to have_link('Declined Requests')
      expect(page).to have_link('All Requests')

      expect(page).not_to have_link('Maintenance Requests')
    end

    scenario 'edit account information' do
      click_link('Edit your account')

      fill_in('user_realname', with: 'John Doe')
      fill_in('user_email', with: 'john.doe@opensuse.org')
      find('input[type="submit"]').click

      expect(page).to have_text("User data for user 'Jim' successfully updated.")
      expect(page).to have_css('#home-realname', text: 'John Doe')
      expect(page).to have_css("a[href='mailto:john.doe@opensuse.org']", text: 'john.doe@opensuse.org')
    end
  end
end
