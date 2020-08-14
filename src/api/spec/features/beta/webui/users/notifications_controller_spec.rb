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

    context 'when clicking on the Comments filter' do
      before do
        login user
        visit my_notifications_path
      end

      it 'shows all unread comment notifications' do
        find('#notifications-dropdown-trigger').click if mobile?
        within('#filters') { click_link('Comments') }
        expect(page).to have_text(notifiable.commentable.name)
      end

      context 'when marking a comment notification as read' do # rubocop:todo RSpec/NestedGroups
        before do
          find('#notifications-dropdown-trigger').click if mobile?
          within('#filters') { click_link('Comments') }
          click_link("update-notification-#{notification_for_projects_comment.id}")
        end

        it 'keeps the Comments filter' do
          wait_for_ajax

          find('#notifications-dropdown-trigger').click if mobile?
          expect(find('.list-group-item.list-group-item-action.active')).to have_text('Comment')
        end
      end
    end

    context 'when clicking on the project filter' do
      before do
        login user
        project.notifications << notification_for_projects_comment
        project.notifications << another_notification_for_projects_comment
        visit my_notifications_path
      end

      it 'shows all unread project notifications' do
        find('#notifications-dropdown-trigger').click if mobile?
        within('#filters') { click_link(project.name) }
        find('#notifications-dropdown-trigger').click if mobile?
        expect(find('.list-group-item.list-group-item-action.active')).to have_text(project.name)
      end

      context 'when marking a project notification as read' do # rubocop:todo RSpec/NestedGroups
        before do
          find('#notifications-dropdown-trigger').click if mobile?
          within('#filters') { click_link(project.name) }
          find_link(id: format('update-notification-%d', notification_for_projects_comment.id)).click
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
