require 'browser_helper'

RSpec.feature 'Notifications', type: :feature, js: true do
  RSpec.shared_examples 'updatable' do
    scenario 'notifications' do
      login user
      visit path

      expect(page).to have_content('Events to get email for')

      %w(subscriptions_8_channel
         subscriptions_7_channel
         subscriptions_14_channel
         subscriptions_15_channel
      ).each do |select_id|
        select('instant_email', from: select_id)
      end

      click_button 'Update'
      expect(page).to have_content('Notifications settings updated')

      # for global Notification settings there is no user_id set
      user_id = user.is_admin? ? nil : user.id

      expect(EventSubscription.exists?(user_id: user_id, eventtype: 'Event::CommentForPackage',
                                       receiver_role: 'commenter', channel: 'instant_email')).to be true
      expect(EventSubscription.exists?(user_id: user_id, eventtype: 'Event::CommentForProject',
                                      receiver_role: 'maintainer', channel: 'instant_email')).to be true
      expect(EventSubscription.exists?(user_id: user_id, eventtype: 'Event::CommentForRequest',
                                       receiver_role: 'reviewer', channel: 'instant_email')).to be true
      expect(EventSubscription.exists?(user_id: user_id, eventtype: 'Event::BuildFail',
                                       receiver_role: 'maintainer', channel: 'instant_email')).to be true
    end
  end

  context 'update as admin user' do
    it_behaves_like 'updatable' do
      let(:user) { create(:admin_user, login: 'king') }
      let(:path) { notifications_path }
    end
  end

  context 'update as unprivileged user' do
    it_behaves_like 'updatable' do
      let(:user) { create(:confirmed_user, login: 'eisendieter') }
      let(:path) { user_notifications_path }
    end
  end
end
