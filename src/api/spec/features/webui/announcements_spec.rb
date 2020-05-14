require 'browser_helper'

RSpec.feature 'Announcements for users', type: :feature, js: true do
  let(:user) { create(:confirmed_user, login: 'tux') }
  let!(:announcement_a) { create(:announcement, message: '### Lorem ipsum Brum Brum A', created_at: 1.minute.ago) }
  let!(:announcement_b) { create(:announcement, message: '### New terms of services B') }

  scenario 'logged in users see an announcement notification and can acknowledge it' do
    login(user)
    visit '/project'
    expect(page).to have_text(announcement_b.message)
    expect(page).to have_link('Read more')
    click_button('Got it')
    expect(page).not_to have_text(announcement_b.message)
    expect(page).not_to have_button('Got it')
  end
end
