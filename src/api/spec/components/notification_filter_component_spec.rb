require 'rails_helper'

RSpec.describe NotificationFilterComponent, type: :component do
  let(:user) { create(:user) }

  before do
    User.session = user
  end

  context 'without projects and groups notifications' do
    before do
      render_inline(described_class.new(selected_filter: { type: 'unread' }))
    end

    ['Unread', 'Read', 'Comments', 'Requests', 'Incoming Requests', 'Outgoing Requests', 'Build Failures'].each do |filter_name|
      it "displays a '#{filter_name}' filter" do
        expect(rendered_content).to have_link(filter_name)
      end
    end

    it "doesn't display project filters" do
      expect(rendered_content).not_to have_css('h5', text: 'Projects')
    end

    it "doesn't display group filters" do
      expect(rendered_content).not_to have_css('h5', text: 'Groups')
    end
  end

  context 'with projects and groups notifications' do
    let!(:notification_for_projects_comment) { create(:web_notification, :comment_for_project, subscriber: user) }
    let(:project) { notification_for_projects_comment.notifiable.commentable }
    let!(:group) { create(:groups_user, user: user, group: create(:group, title: 'Les_Colocs')).group }

    before do
      project.notifications << notification_for_projects_comment
      group.created_notifications << notification_for_projects_comment
      render_inline(described_class.new(selected_filter: { type: 'unread' }))
    end

    ['Unread', 'Read', 'Comments', 'Requests', 'Incoming Requests', 'Outgoing Requests', 'Build Failures'].each do |filter_name|
      it "displays a '#{filter_name}' filter" do
        expect(rendered_content).to have_link(filter_name)
      end
    end

    it 'displays project filters' do
      expect(rendered_content).to have_css('h5', text: 'Projects')
      expect(rendered_content).to have_link(project.name)
    end

    it 'displays group filters' do
      expect(rendered_content).to have_css('h5', text: 'Groups')
      expect(rendered_content).to have_link(group.title)
    end
  end
end
