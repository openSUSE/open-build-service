require 'browser_helper'

RSpec.feature 'Announcements for users', type: :feature, js: true do
  let(:user) { create(:confirmed_user, login: 'tux') }
  let!(:announcement_a) { create(:announcement, title: 'New terms of services A', content: 'Lorem ipsum A', created_at: 1.minute.ago) }
  let!(:announcement_b) { create(:announcement, title: 'New terms of services B', content: 'Lorem ipsum B') }

  scenario "logged in users see a 'new announcements' notification and can acknowledge it" do
    skip_if_bootstrap

    login(user)
    visit '/'
    expect(page).to have_text('There has been new announcements!')
    expect(page).to have_link('Read more')
    click_button('Got it')
    expect(page).not_to have_text('There has been new announcements!')
    expect(page).not_to have_button('Got it')
  end
end
