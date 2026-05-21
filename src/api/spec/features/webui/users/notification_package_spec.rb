require 'browser_helper'

# NotificationPackage inherits from Notification

RSpec.describe 'NotificationPackage', :js do
  let!(:user) { create(:confirmed_user) }
  let(:package) { create(:package_with_maintainer, maintainer: user) }
  let(:event_payload) { { package: package.name, project: package.project.name } }

  context 'upstream version changed on a package' do
    let!(:notification) { create(:notification_for_package, :web_notification, :upstream_version, subscriber: user, notifiable: package, event_payload: event_payload) }

    before do
      login user
      visit my_notifications_path
    end

    it 'contains a link pointing to the report' do
      expect(page).to have_link("New upstream version for #{notification.notifiable.name}",
                                href: "/package/show/#{notification.notifiable.project.name}/#{notification.notifiable.name}?notification_id=#{notification.id}")
    end

    it 'contains a description' do
      expect(page).to have_text("The upstream version of package #{notification.notifiable.project.name} / #{notification.notifiable.name}")
    end
  end

  # TODO: move from other specs or implement the following contexts:
  # - context 'build failed on a package'
  # - context 'added relationship with a package'
  # - context 'removed relationship with a package'
end
