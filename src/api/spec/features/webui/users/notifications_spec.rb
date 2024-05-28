require 'browser_helper'

RSpec.describe 'User notifications', :js do
  let!(:user) { create(:confirmed_user) }

  describe 'when having no notifications' do
    context 'when accessing the notifications page' do
      before do
        login user
        visit my_notifications_path
      end

      it 'shows no notifications' do
        expect(page).to have_text('There are no notifications')
      end
    end
  end

  describe 'when having notifications' do
    let!(:notification_for_projects_comment) { create(:web_notification, :comment_for_package, subscriber: user) }
    let!(:another_notification_for_projects_comment) { create(:web_notification, :comment_for_package, subscriber: user) }
    let(:notifiable) { notification_for_projects_comment.notifiable }
    let(:another_notifiable) { another_notification_for_projects_comment.notifiable }
    let(:project) { notifiable.commentable.project }

    before do
      login user
      visit my_notifications_path
    end

    context 'when clicking on the Comments filter' do
      before do
        find_by_id('notifications-dropdown-trigger').click if mobile?
        within('#filters') { check('Comments') }
        click_button('filter-button') # apply the filters
      end

      it 'shows all unread comment notifications' do
        expect(page).to have_text(notifiable.commentable.name)
      end
    end

    context 'when marking multiple comment notifications as read' do
      before do
        find_by_id('notifications-dropdown-trigger').click if mobile? # open the filter dropdown
        within('#filters') { check('Comments') }
        click_button('filter-button') # apply the filters
        toggle_checkbox("notification_ids_#{notification_for_projects_comment.id}")
        toggle_checkbox("notification_ids_#{another_notification_for_projects_comment.id}")
        click_button('read-button')
      end

      it 'marks all comment notification as read' do
        wait_for_ajax

        expect(page).to have_text('There are no notifications for the current filter selection')
      end
    end

    context 'when clicking on the project filter' do
      before do
        project.notifications << notification_for_projects_comment
        project.notifications << another_notification_for_projects_comment
        # need to load the page again in order to have the notifications
        # visible
        visit my_notifications_path
      end

      it 'shows all unread project notifications' do
        find_by_id('notifications-dropdown-trigger').click if mobile? # open the filter dropdown
        within('#filters') { check(project.name) }
        click_button('filter-button') # apply the filters

        expect(page).to have_text(notification_for_projects_comment.notifiable.commentable_type)
      end
    end

    context 'when having less notifications than the maximum per page' do
      it { expect(page).to have_no_text("Mark all as 'Read'") }
    end

    context 'when having more notifications than the maximum per page' do
      before do
        # Instead of creating Notification::MAX_PER_PAGE + 1 notifications, we better reduce the constant value.
        # The total amount of notifications exceeds the maximum per page, so the button should be displayed.
        stub_const('Notification::MAX_PER_PAGE', 1)
        visit my_notifications_path
      end

      it { expect(page).to have_text("Mark all as 'Read'") }
    end
  end
end
