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
    let!(:notification_for_projects_comment) { create(:notification_for_comment, :web_notification, :comment_for_package, subscriber: user) }
    let!(:another_notification_for_projects_comment) { create(:notification_for_comment, :web_notification, :comment_for_package, subscriber: user) }
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
        within('#content-selector-filters') { check('Comments') }
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
        within('#content-selector-filters') do
          within('#notification-filter-projects') do
            check(project.name)
          end
        end

        expect(page).to have_text(notification_for_projects_comment.notifiable.commentable_type)
      end
      # rubocop:enable RSpec/ExampleLength
    end

    context 'when clicking on the request filter' do
      let!(:notification_for_request) { create(:notification_for_request, :web_notification, :request_state_change, subscriber: user) }
      let!(:another_notification_for_request) { create(:notification_for_request, :web_notification, :request_created, subscriber: user) }
      let(:bs_request) { notification_for_request.notifiable }

      before do
        bs_request.notifications << notification_for_request
        bs_request.notifications << another_notification_for_request
        # need to load the page again in order to have the notifications
        # visible
        visit my_notifications_path
      end

      # rubocop:disable RSpec/ExampleLength
      it 'shows all unread request notifications' do
        find_by_id('notifications-dropdown-trigger').click if mobile? # open the filter dropdown
        within('#content-selector-filters') do
          within('#notification-filter-requests') do
            check('new')
          end
        end

        expect(page).to have_text(notification_for_request.notifiable.number)
      end
      # rubocop:enable RSpec/ExampleLength
    end

    context 'when having less notifications than the maximum per page' do
      it { expect(page).to have_no_text("Mark all as 'Read'") }
    end
  end

  context 'when the notification is about a relationship with package' do
    let(:package) { create(:package_with_maintainer, maintainer: user) }
    let(:event_payload) { { package: package.name, project: package.project.name } }
    let!(:notification) { create(:notification_for_project, :web_notification, :relationship_create_for_project, notifiable: package, event_payload: event_payload, subscriber: user) }

    before do
      login user
      visit my_notifications_path
    end

    it 'renders the correct icon' do
      expect(page).to have_css("i.fa-user-tag[title='Relationship notification']")
    end
  end

  context 'when the notification is about a comment for project' do
    let(:project) { create(:project, maintainer: user) }
    let(:comment) { create(:comment, commentable: project) }
    let!(:notification) { create(:notification_for_comment, :web_notification, :comment_for_project, notifiable: comment, subscriber: user) }

    before do
      login user
      visit my_notifications_path
    end

    it 'renders the correct icon' do
      expect(page).to have_css("i.fa-comments[title='Comment notification']")
    end
  end

  context 'reports' do
    let(:accused) { create(:confirmed_user, login: 'accused') }
    let!(:notification) { create(:notification_for_report, :web_notification, event_payload: event_payload, event_type: event_type, notifiable: notifiable, subscriber: accused) }

    before do
      login accused
      visit my_notifications_path
    end

    context 'when the notification is about user' do
      let(:event_payload) { { reporter: user.login, reportable_id: accused.id, reportable_type: 'User', reason: 'some sample text for reason field', category: 'spam', accused: accused.login } }
      let(:event_type) { 'Event::ReportForUser' }
      let(:notifiable) { create(:report, reportable: accused, reason: 'Some sample text') }

      it 'renders information about user state' do
        skip_on_mobile
        expect(page).to have_css('span', text: accused.state, class: 'badge')
      end
    end

    context 'when the notification is about comment' do
      let(:project) { create(:project, maintainer: user) }
      let(:comment) { create(:comment, commentable: project) }
      let(:event_type) { 'Event::ReportForComment' }
      let(:notifiable) { create(:report, reportable: comment, reason: 'Some sample text') }
      let(:event_payload) { { reporter: user.login, reportable_id: comment.id, reportable_type: 'Comment', reason: 'some sample text for reason field', category: 'spam' } }

      it 'renders information about user state and its existing reports' do
        skip_on_mobile
        expect(page).to have_css('span', text: accused.state, class: 'badge')
        expect(page).to have_css('span', text: '+1', class: 'badge')
      end
    end

    context 'when the reportable of the notification has additional reports and no decision' do
      let(:project) { create(:project, maintainer: accused) }
      let(:comment) { create(:comment, commentable: project) }
      let(:event_type) { 'Event::ReportForComment' }
      let!(:notifiable) { create(:report, reportable: comment, reason: 'Some sample text') }
      let(:event_payload) { { reporter: user.login, reportable_id: comment.id, reportable_type: 'Comment', reason: 'some sample text for reason field', category: 'spam' } }
      let!(:additional_report) { create(:report, reportable: comment, reason: 'This is spam') }

      it 'renders a badge that indicates that there are more reports' do
        skip_on_mobile
        expect(page).to have_css('span', text: '+1 reported', class: 'badge')
      end

      it 'renders a badge that indicates that the report waits for a decision' do
        expect(page).to have_css('span', text: 'Awaits decision', class: 'badge')
      end
    end

    context 'when the report of the notification has a decision' do
      let(:project) { create(:project, maintainer: accused) }
      let(:comment) { create(:comment, commentable: project) }
      let(:event_type) { 'Event::ReportForComment' }
      let(:notifiable) { create(:report, reportable: comment, reason: 'Some sample text') }
      let(:event_payload) { { reporter: accused.login, reportable_id: comment.id, reportable_type: 'Comment', reason: 'some sample text for reason field', category: 'spam' } }
      let!(:decision) { create(:decision_favored, reports: [notifiable]) }

      before do
        login accused
        visit my_notifications_path
      end

      it 'renders a badge that indicates that a decision was made for the report' do
        expect(page).to have_css('span', text: 'Decided', class: 'badge')
      end
    end
  end
end
