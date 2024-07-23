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
end
