require 'browser_helper'

RSpec.describe 'User notifications', type: :feature, js: true do
  let!(:user) { create(:confirmed_user, :in_beta) }

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

    shared_examples 'keeps the Comments filter' do
      it 'keeps the filter' do
        wait_for_ajax

        find('#notifications-dropdown-trigger').click if mobile?
        expect(find('.list-group-item.list-group-item-action.active')).to have_text('Comment')
      end
    end

    before do
      login user
      visit my_notifications_path
    end

    context 'when clicking on the Comments filter' do
      before do
        find('#notifications-dropdown-trigger').click if mobile?
        within('#filters') { click_link('Comments') }
      end

      it 'shows all unread comment notifications' do
        expect(page).to have_text(notifiable.commentable.name)
      end

      context 'when marking a comment notification as read' do
        before do
          click_link("update-notification-#{notification_for_projects_comment.id}")
        end

        it_behaves_like 'keeps the Comments filter'
      end
    end

    context 'when marking multiple comment notifications as read' do
      before do
        find('#notifications-dropdown-trigger').click if mobile?
        within('#filters') { click_link('Comments') }
        toggle_checkbox("notification_ids_#{notification_for_projects_comment.id}")
        toggle_checkbox("notification_ids_#{another_notification_for_projects_comment.id}")
        click_button('done-button')
      end

      it 'marks all comment notification as read' do
        wait_for_ajax

        expect(page).to have_text('There are no notifications for this filter')
      end

      it_behaves_like 'keeps the Comments filter'
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
        find('#notifications-dropdown-trigger').click if mobile?
        within('#filters') { click_link(project.name) }
        find('#notifications-dropdown-trigger').click if mobile?
        expect(find('.list-group-item.list-group-item-action.active')).to have_text(project.name)
      end

      context 'when marking a project notification as read' do
        before do
          find('#notifications-dropdown-trigger').click if mobile?
          within('#filters') { click_link(project.name) }
        end

        it 'keeps the project filter' do
          wait_for_ajax
          find('#notifications-dropdown-trigger').click if mobile?
          expect(find('.list-group-item.list-group-item-action.active')).to have_text(project.name)
        end
      end
    end
  end
end
