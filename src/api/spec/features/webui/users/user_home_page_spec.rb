require 'browser_helper'

RSpec.describe "User's home project creation", type: :feature, js: true do
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

    it 'view home page of another user' do
      expect(page).to have_css('#home-realname', text: 'Jim Knopf')
      expect(page).not_to have_css("a[href='mailto:jim.knopf@puppenkiste.com']", text: 'jim.knopf@puppenkiste.com')

      expect(page).not_to have_text('Edit Your account')
      expect(page).not_to have_text('Change Your password')

      expect(page).to have_link('Involved Packages')
      expect(page).to have_link('Involved Projects')
      expect(page).to have_link('Owned Projects/Packages')
    end
  end

  describe 'as a logged-in user' do
    before do
      login user
      visit user_path(user)
    end

    it 'view home page' do
      expect(page).to have_css('#home-realname', text: 'Jim Knopf')
      expect(page).to have_css("a[href='mailto:jim.knopf@puppenkiste.com']", text: 'jim.knopf@puppenkiste.com')

      within('#bottom-navigation-area') { click_link('Actions') } if mobile?
      expect(page).to have_text('Edit Your Account')
      expect(page).to have_text('Change Your Password')

      expect(page).to have_link('Involved Packages')
      expect(page).to have_link('Involved Projects')
      expect(page).to have_link('Owned Projects/Packages')
    end

    it 'view tasks page' do
      visit my_tasks_path

      expect(page).to have_link('Incoming Requests')
      within('#requests') { find('.nav-link.dropdown-toggle').click } if mobile?
      expect(page).to have_link('Outgoing Requests')
      expect(page).to have_link('Declined Requests')
      expect(page).to have_link('All Requests')

      expect(page).not_to have_link('Maintenance Requests')
    end

    it 'edit account information' do
      if mobile?
        within('#bottom-navigation-area') { click_link('Actions') }
        within('#bottom-navigation-area') { click_link('Edit Your Account') }
      else
        click_link('Edit Your Account')
      end

      fill_in('user_realname', with: 'John Doe')
      fill_in('user_email', with: 'john.doe@opensuse.org')
      find('input[type="submit"]').click

      expect(page).to have_text("User data for user 'Jim' successfully updated.")
      expect(page).to have_css('#home-realname', text: 'John Doe')
      expect(page).to have_css("a[href='mailto:john.doe@opensuse.org']", text: 'john.doe@opensuse.org')
    end
  end
end
