require 'browser_helper'

RSpec.describe 'NotificationUser', :js do
  let(:user) { create(:confirmed_user) }
  let(:admin_user) { create(:admin_user) }
  let(:event_payload) { { role: 'Admin', who: admin_user.login, user: user.login } }

  context 'upstream version changed on a package' do
    let!(:notification) { create(:notification_for_global_role_assignment, subscriber: user, notifiable: user, event_payload: event_payload) }

    before do
      login user
      visit my_notifications_path
    end

    it 'contains a link pointing to the user' do
      expect(page).to have_link('New Global Role Assigned',
                                href: "/users/#{user.login}?notification_id=#{notification.id}")
    end
  end
end
