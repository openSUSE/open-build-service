require 'browser_helper'

RSpec.describe 'OBS main page', :js, :vcr do
  let(:admin_user) { create(:admin_user) }
  let(:user) { create(:confirmed_user) }

  describe '#index' do
    it 'shows the latest four status messages' do
      (1..5).each do |n|
        # Make sure created_at timestamps differ
        travel_to((5 - n).seconds.ago) { create(:status_message, message: "message #{n}", creator: admin_user) }
      end

      visit root_path

      expect(page).to have_text('message 2')
      expect(page).to have_text('message 3')
      expect(page).to have_text('message 4')
      expect(page).to have_text('message 5')
      expect(page).to have_no_text('message 1')
    end

    describe 'latest updates' do
      context 'when user is logged in' do
        before do
          login user
        end

        it 'shows user commit activities in My Updates tab' do
          visit root_path
          click_link 'My Updates'
          expect(page).to have_text('No recent activity')

          CommitActivity.create!(user: user, project: 'MyProject', package: 'MyPackage', date: Time.zone.today, count: 1)

          visit root_path
          click_link 'My Updates'

          expect(page).to have_link('MyProject')
          expect(page).to have_link('MyPackage')
        end
      end
    end
  end
end
