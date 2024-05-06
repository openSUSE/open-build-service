RSpec.describe NotificationFilterComponent, type: :component do
  let(:user) { create(:user) }
  let(:relations) { user.notifications.for_web }

  before do
    Flipper.disable(:content_moderation)
    User.session = user
  end

  context 'without projects and groups notifications' do
    before do
      render_inline(described_class.new(relations: relations, selected_filter: { unread: 1 }, user: user))
    end

    ['Unread', 'Read', 'Comments', 'Requests', 'Incoming Requests', 'Outgoing Requests', 'Build Failures'].each do |filter_name|
      it "displays a '#{filter_name}' filter" do
        expect(rendered_content).to have_field(filter_name)
      end
    end

    it "doesn't display project filters" do
      expect(rendered_content).to have_no_css('h6 b', text: 'Projects')
    end

    it "doesn't display group filters" do
      expect(rendered_content).to have_no_css('h6 b', text: 'Groups')
    end

    it "doesn't display the Reports filter" do
      expect(rendered_content).to have_no_link('Reports')
    end
  end

  context 'with projects and groups notifications' do
    let!(:notification_for_projects_comment) { create(:web_notification, :comment_for_project, subscriber: user) }
    let(:project) { notification_for_projects_comment.notifiable.commentable }
    let!(:group) { create(:groups_user, user: user, group: create(:group, title: 'Les_Colocs')).group }

    before do
      project.notifications << notification_for_projects_comment
      group.created_notifications << notification_for_projects_comment
      render_inline(described_class.new(relations: relations, selected_filter: { unread: 1 }, user: user))
    end

    ['Unread', 'Read', 'Comments', 'Requests', 'Incoming Requests', 'Outgoing Requests', 'Build Failures'].each do |filter_name|
      it "displays a '#{filter_name}' filter" do
        expect(rendered_content).to have_field(filter_name)
      end
    end

    it 'displays project filters' do
      expect(rendered_content).to have_css('h6 b', text: 'Projects')
      expect(rendered_content).to have_field(project.name)
    end

    it 'displays group filters' do
      expect(rendered_content).to have_css('h6 b', text: 'Groups')
      expect(rendered_content).to have_field(group.title)
    end
  end

  context 'when content moderation is true' do
    let(:user) { create(:moderator) }

    before do
      Flipper.enable(:content_moderation)
      render_inline(described_class.new(relations: relations, selected_filter: { type: 'unread' }, user: user))
    end

    it 'displays the Reports filter' do
      expect(rendered_content).to have_field('Reports')
    end

    it 'displays the Appeals filter' do
      expect(rendered_content).to have_field('Appealed Decisions')
    end
  end
end
