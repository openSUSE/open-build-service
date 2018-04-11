# frozen_string_literal: true

require 'browser_helper'

RSpec.feature 'OBS main page', type: :feature, js: true do
  let(:admin_user) { create(:admin_user) }
  let(:user) { create(:confirmed_user) }

  describe '#index' do
    it 'shows the latest four status messages' do
      (1..5).each do |n|
        create(:status_message, message: "message #{n}", user: admin_user)
        # Make sure created_at timestamps differ
        Timecop.travel(1.second)
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
