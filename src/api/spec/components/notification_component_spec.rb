RSpec.describe NotificationComponent, type: :component do
  let(:user) { create(:confirmed_user) }
  let(:selected_filter) { {} }

  context 'when the notification is about a relationship with package' do
    let(:package) { create(:package_with_maintainer, maintainer: user) }
    let(:event_payload) { { package: package.name, project: package.project.name } }
    let(:notification) { create(:notification_for_project, :relationship_create_for_project, delivered: true, notifiable: package, event_payload: event_payload) }

    before do
      render_inline(described_class.new(notification: notification, selected_filter: selected_filter, page: 1))
    end

    it 'renders the correct icon' do
      expect(rendered_content).to have_css("i.fa-user-tag[title='Relationship notification']")
    end
  end

  context 'when the notification is about a comment for project' do
    let(:project) { create(:project, maintainer: user) }
    let(:comment) { create(:comment, commentable: project) }
    let(:notification) { create(:notification_for_comment, :comment_for_project, delivered: true, notifiable: comment) }

    before do
      render_inline(described_class.new(notification: notification, selected_filter: selected_filter, page: 1))
    end

    it 'renders the correct icon' do
      expect(rendered_content).to have_css("i.fa-comments[title='Comment notification']")
    end
  end

  context 'reports' do
    let(:accused) { create(:confirmed_user, login: 'accused') }
    let(:notification) { create(:notification_for_report, event_payload: event_payload, event_type: event_type, notifiable: notifiable) }

    before do
      render_inline(described_class.new(notification: notification, selected_filter: selected_filter, page: 1))
    end

    context 'when the notification is about user' do
      let(:event_payload) { { reporter: user.login, reportable_id: accused.id, reportable_type: 'User', reason: 'some sample text for reason field', category: 'spam', accused: accused.login } }
      let(:event_type) { 'Event::ReportForUser' }
      let(:notifiable) { create(:report, reportable: accused, reason: 'Some sample text') }

      it 'renders information about user state' do
        expect(rendered_content).to have_css('span', text: accused.state, class: 'badge')
      end
    end

    context 'when the notification is about comment' do
      let(:project) { create(:project, maintainer: user) }
      let(:comment) { create(:comment, commentable: project) }
      let(:event_type) { 'Event::ReportForComment' }
      let(:notifiable) { create(:report, reportable: comment, reason: 'Some sample text') }
      let(:event_payload) { { reporter: user.login, reportable_id: comment.id, reportable_type: 'Comment', reason: 'some sample text for reason field', category: 'spam' } }

      it 'renders information about user state and its existing reports' do
        expect(rendered_content).to have_css('span', text: accused.state, class: 'badge')
        expect(rendered_content).to have_css('span', text: '+1', class: 'badge')
      end
    end
  end
end
