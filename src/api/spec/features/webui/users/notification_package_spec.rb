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

  context 'when clicking on the package filter' do
    let(:another_package) { create(:package_with_maintainer, maintainer: user) }
    let(:event_payload_another) { { package: another_package.name, project: another_package.project.name } }
    let!(:notification_for_another_package) do
      create(:notification_for_package, :web_notification, :upstream_version, subscriber: user,
             notifiable: another_package, event_payload: event_payload_another)
    end
    let!(:notification) { create(:notification_for_package, :web_notification, :upstream_version, subscriber: user, notifiable: package, event_payload: event_payload) }

    before do
      login user
      visit my_notifications_path

      find_by_id('notifications-dropdown-trigger').click if mobile?
      within('#notification-package-name-dropdown') do
        fill_in 'package[]', with: package.name
        find('button:has(i.fa-search)').click
      end
    end

    it 'shows only notifications for the selected package' do
      expect(page).to have_text(package.name)
      expect(page).to have_no_text(another_package.name)
    end
  end

  context 'when filtering by package and a comment notification exists for that package' do
    let(:comment) { create(:comment_package, commentable: package) }
    let!(:comment_notification) do
      create(:notification_for_comment, :web_notification, :comment_for_package, subscriber: user, notifiable: comment)
    end
    let!(:package_notification) { create(:notification_for_package, :web_notification, :upstream_version, subscriber: user, notifiable: package, event_payload: event_payload) }
    let(:other_package) { create(:package_with_maintainer, maintainer: user) }
    let!(:other_notification) do
      create(:notification_for_package, :web_notification, :upstream_version, subscriber: user,
             notifiable: other_package, event_payload: { package: other_package.name, project: other_package.project.name })
    end

    before do
      login user
      visit my_notifications_path

      find_by_id('notifications-dropdown-trigger').click if mobile?
      within('#notification-package-name-dropdown') do
        fill_in 'package[]', with: package.name
        find('button:has(i.fa-search)').click
      end
    end

    it 'shows both the package notification and the comment notification for the selected package' do
      expect(page).to have_link("New upstream version for #{package.name}")
      expect(page).to have_link('Comment on Package')
      expect(page).to have_no_text(other_package.name)
    end
  end

  context 'when filtering by package and a request notification exists for that package' do
    let(:bs_request) do
      create(:bs_request_with_submit_action, source_package: package.name,
             target_package: package.name, source_project: package.project,
             target_project: package.project)
    end
    let!(:request_notification) do
      create(:notification_for_request, :web_notification, :request_state_change,
             subscriber: user, notifiable: bs_request)
    end
    let!(:package_notification) do
      create(:notification_for_package, :web_notification, :upstream_version,
             subscriber: user, notifiable: package, event_payload: event_payload)
    end
    let(:other_package) { create(:package_with_maintainer, maintainer: user) }
    let!(:other_notification) do
      create(:notification_for_package, :web_notification, :upstream_version, subscriber: user,
             notifiable: other_package, event_payload: { package: other_package.name, project: other_package.project.name })
    end

    before do
      login user
      visit my_notifications_path

      find_by_id('notifications-dropdown-trigger').click if mobile?
      within('#notification-package-name-dropdown') do
        fill_in 'package[]', with: package.name
        find('button:has(i.fa-search)').click
      end
    end

    it 'shows both the package notification and the request notification for the selected package' do
      expect(page).to have_link("New upstream version for #{package.name}")
      expect(page).to have_link("Submit Request ##{bs_request.number}")
      expect(page).to have_no_text(other_package.name)
    end
  end

  context 'when filtering by package and a report notification exists for that package' do
    let(:report) { create(:report, reportable: package) }
    let!(:report_notification) do
      create(:notification_for_report, :web_notification, :report_for_package,
             subscriber: user,
             notifiable: report,
             event_payload: { 'id' => report.id,
                              'reportable_type' => 'Package',
                              'package_name' => package.name,
                              'project_name' => package.project.name })
    end
    let!(:package_notification) do
      create(:notification_for_package, :web_notification, :upstream_version,
             subscriber: user, notifiable: package, event_payload: event_payload)
    end
    let(:other_package) { create(:package_with_maintainer, maintainer: user) }
    let!(:other_notification) do
      create(:notification_for_package, :web_notification, :upstream_version, subscriber: user,
             notifiable: other_package, event_payload: { package: other_package.name, project: other_package.project.name })
    end

    before do
      login user
      visit my_notifications_path(package: [package.name])
    end

    it 'shows the report notification for the selected package' do
      expect(page).to have_text("Report for Package #{package.project.name} / #{package.name}")
    end

    it 'does not show notifications for other packages' do
      expect(page).to have_no_text(other_package.name)
    end
  end

  # TODO: move from other specs or implement the following contexts:
  # - context 'build failed on a package'
  # - context 'added relationship with a package'
  # - context 'removed relationship with a package'
end
