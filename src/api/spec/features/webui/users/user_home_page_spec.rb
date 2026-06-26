require 'browser_helper'

RSpec.describe "User's home project creation", :js do
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
      expect(page).to have_no_link('jim.knopf@puppenkiste.com', href: 'mailto:jim.knopf@puppenkiste.com')

      expect(page).to have_no_link('Edit Your Account')
      expect(page).to have_no_link('Change Your Password')

      if mobile?
        expect(page).to have_text('Involved Projects and Packages')
      else
        expect(page).to have_link('Involved Projects/Packages')
      end
    end
  end

  describe 'as a logged-in user' do
    before do
      login user
      visit user_path(user)
    end

    it 'view home page' do
      expect(page).to have_css('#home-realname', text: 'Jim Knopf')
      expect(page).to have_link('jim.knopf@puppenkiste.com', href: 'mailto:jim.knopf@puppenkiste.com')

      expect(page).to have_link('Edit Your Account')

      if mobile?
        expect(page).to have_text('Involved Projects and Packages')
        within('#bottom-navigation-area') { click_link('Actions') }
      else
        expect(page).to have_link('Involved Projects/Packages')
      end

      expect(page).to have_link('Change Your Password')
    end

    it 'view tasks page' do
      visit my_tasks_path

      expect(page).to have_link('Incoming Requests')
      within('#requests') { find('.nav-link.dropdown-toggle').click } if mobile?
      expect(page).to have_link('Outgoing Requests')
      expect(page).to have_link('Declined Requests')
      expect(page).to have_link('All Requests')

      expect(page).to have_no_link('Maintenance Requests')
    end

    it 'edit account information' do
      click_link('Edit Your Account')

      fill_in('user_realname', with: 'John Doe')
      fill_in('user_email', with: 'john.doe@opensuse.org')
      find('input[type="submit"]').click

      expect(page).to have_text("User data for user 'Jim' successfully updated.")
      expect(page).to have_css('#home-realname', text: 'John Doe')
      expect(page).to have_link('john.doe@opensuse.org', href: 'mailto:john.doe@opensuse.org')
    end
  end
end
