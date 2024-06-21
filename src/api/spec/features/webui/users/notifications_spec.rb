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
      end

      it 'shows all unread comment notifications' do
        expect(page).to have_text(notifiable.commentable.name)
      end
    end

    context 'when marking multiple comment notifications as read' do
      before do
        visit my_notifications_path({ kind: 'comments' })
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

      # rubocop:disable RSpec/ExampleLength
      it 'shows all unread project notifications' do
        find_by_id('notifications-dropdown-trigger').click if mobile? # open the filter dropdown
        within('#filters') do
          click_button('filter-projects-button') # open the filter
          check(project.name)
          click_button('filter-projects-button') # close the filter
        end

        expect(page).to have_text(notification_for_projects_comment.notifiable.commentable_type)
      end
      # rubocop:enable RSpec/ExampleLength
    end

    context 'when having less notifications than the maximum per page' do
      it { expect(page).to have_no_text("Mark all as 'Read'") }
    end
  end
end
