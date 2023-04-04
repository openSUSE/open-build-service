require 'browser_helper'

RSpec.describe 'OBS main page', js: true, vcr: true do
  let(:admin_user) { create(:admin_user) }
  let(:user) { create(:confirmed_user) }

  describe '#index' do
    it 'shows the latest four status messages' do
      (1..5).each do |n|
        # Make sure created_at timestamps differ
        travel_to((5 - n).seconds.ago) { create(:status_message, message: "message #{n}", user: admin_user) }
      end

      visit root_path

      expect(page).not_to have_content('message 1')
      expect(page).to have_content('message 2')
      expect(page).to have_content('message 3')
      expect(page).to have_content('message 4')
      expect(page).to have_content('message 5')
    end
  end
end
