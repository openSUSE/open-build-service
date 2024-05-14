require 'browser_helper'

RSpec.describe 'Subscriptions', :js do
  RSpec.shared_examples 'updatable' do
    it 'notifications' do
      login user
      visit path

      expect(page).to have_content(title)
      notification_field = find('.card-body h5', text: 'Package failed to build').sibling('.list-group')
      %w[maintainer bugowner reader project_watcher].each do |role|
        subscription_by_role = notification_field.find(".#{role}")
        subscription_by_role.check('email')
        expect(page).to have_css('#flash', text: 'Notifications settings updated')
        find('#flash button[data-bs-dismiss]').click
      end

      visit path

      notification_field = find('.card-body h5', text: 'Package failed to build').sibling('.list-group')
      %w[maintainer bugowner reader project_watcher].each do |role|
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
      let(:title) { 'Choose events you want to get notified about and the corresponding channels.' }
      let(:user) { create(:confirmed_user, login: 'eisendieter') }
      let(:path) { my_subscriptions_path }
    end
  end

  context 'update group notifications settings' do
    let(:user) { create(:confirmed_user, login: 'Tom') }
    let!(:group) { create(:group_with_user, title: 'test', user: user) }

    it "disable a group's notifications for email and web channels" do
      login user
      visit my_subscriptions_path

      find("label[for='groups_#{group}_web']").click
      find("label[for='groups_#{group}_email']").click

      visit my_subscriptions_path

      expect(find_field("groups_#{group}_web", visible: false)).not_to be_checked
      expect(find_field("groups_#{group}_email", visible: false)).not_to be_checked
    end
  end
end
