require 'browser_helper'

RSpec.feature 'Notifications', type: :feature, js: true do
  RSpec.shared_examples 'updatable' do
    scenario 'notifications' do
      login user
      visit path

      expect(page).to have_content(title)
      notification_field = find('.card-body h5', text: 'Package has failed to build').sibling('.list-group')
      ['maintainer', 'bugowner', 'reader', 'watcher'].each do |role|
        subscription_by_role = notification_field.find(".#{role}")
        subscription_by_role.check('email', allow_label_click: true)
        expect(page).to have_css('#flash', text: 'Notifications settings updated')
        find('#flash button[data-dismiss]').click
      end

      visit path

      notification_field = find('.card-body h5', text: 'Package has failed to build').sibling('.list-group')
      ['maintainer', 'bugowner', 'reader', 'watcher'].each do |role|
        subscription_by_role = notification_field.find(".#{role}")
        expect(subscription_by_role.find_field('email', visible: false)).to be_checked
      end
    end
  end

  context 'update as admin user' do
    it_behaves_like 'updatable' do
      let(:title) { 'Notifications' }
      let(:user) { create(:admin_user, login: 'king') }
      let(:path) { notifications_path }
    end
  end

  context 'update as unprivileged user' do
    it_behaves_like 'updatable' do
      let(:title) { 'Choose from which events you want to get an email' }
      let(:user) { create(:confirmed_user, login: 'eisendieter') }
      let(:path) { my_subscriptions_path }
    end
  end
end
