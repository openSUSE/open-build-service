require 'browser_helper'

RSpec.describe 'OBS main page', :js, :vcr do
  let(:admin_user) { create(:admin_user) }
  let(:user) { create(:confirmed_user) }

  describe '#index' do
    it 'shows the latest four status messages' do
      (1..5).each do |n|
        # Make sure created_at timestamps differ
        travel_to((5 - n).seconds.ago) { create(:status_message, message: "message #{n}", user: admin_user) }
      end

      visit root_path

      expect(page).to have_text('message 2')
      expect(page).to have_text('message 3')
      expect(page).to have_text('message 4')
      expect(page).to have_text('message 5')
      expect(page).to have_no_text('message 1')
    end
  end
end
