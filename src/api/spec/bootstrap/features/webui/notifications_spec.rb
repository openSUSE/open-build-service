require 'browser_helper'

RSpec.feature 'Notifications', type: :feature, js: true do
  RSpec.shared_examples 'updatable' do
    scenario 'notifications' do
      login user
      visit path

      expect(page).to have_content(title)
      notification_field = find('.card-body h5', text: 'Package has failed to build').sibling('.form-inline')
      ['Maintainer', 'Bugowner', 'Reader', 'Watching the project'].each do |label|
        notification_field.check(label, allow_label_click: true)
        expect(page).to have_css('#flash', text: 'Notifications settings updated')
        find('#flash button[data-dismiss]').click
      end

      visit path

      notification_field = find('.card-body h5', text: 'Package has failed to build').sibling('.form-inline')
      ['Maintainer', 'Bugowner', 'Reader', 'Watching the project'].each do |label|
        expect(notification_field.find_field(label, visible: false)).to be_checked
      end
    end
  end

  context 'update as admin user' do
    it_behaves_like 'updatable' do
      let(:title) { is_bootstrap? ? 'Notifications' : 'Global Notification Settings' }
      let(:user) { create(:admin_user, login: 'king') }
      let(:path) { notifications_path }
    end
  end

  context 'update as unprivileged user' do
    it_behaves_like 'updatable' do
      let(:title) { 'Choose from which events you want to get an email' }
      let(:user) { create(:confirmed_user, login: 'eisendieter') }
      let(:path) { user_notifications_path }
    end
  end
end
