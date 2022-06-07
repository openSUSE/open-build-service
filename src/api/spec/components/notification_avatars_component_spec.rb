require 'rails_helper'

RSpec.describe NotificationAvatarsComponent, type: :component do
  context 'when a notification has more avatars to display than defined in MAXIMUM_DISPLAYED_AVATARS' do
    let(:project) { create(:project) }
    let(:comment_for_project) { create(:comment, commentable: project) }
    let(:notification) { create(:notification, :comment_for_project, notifiable: comment_for_project, last_seen_at: 1.day.ago) }

    before do
      # Comment which was already read (it's older than the notification), so it's not taken into account in the notification
      create(:comment, commentable: project, updated_at: 2.days.ago)

      # Extra unread comments (on top of the comment/notifiable for the notification)
      create_list(:comment, 6, commentable: project)

      render_inline(described_class.new(notification))
    end

    it 'renders an extra avatar for other users involved' do
      expect(rendered_content).to have_selector('li.list-inline-item > span[title="1 more users involved"]')
    end

    it 'renders an avatar for each user up to the limit MAXIMUM_DISPLAYED_AVATARS' do
      expect(rendered_content).to have_selector('li.list-inline-item > img', count: 6)
    end
  end

  context 'for a BsRequest notification with various reviews' do
    let(:group) { create(:group, title: 'Canailles') }
    let(:user) { create(:confirmed_user, realname: 'Jane Doe') }
    let(:project) { create(:project, name: 'project2') }
    let(:project_for_package) { create(:project, name: 'project1') }
    let(:package) { create(:package, project: project_for_package, name: 'package1') }
    let(:creator) { create(:confirmed_user, realname: 'Johnny Dupuis') }
    let(:bs_request) do
      create(:bs_request_with_submit_action, review_by_group: group,
                                             review_by_user: user,
                                             review_by_project: project,
                                             review_by_package: package, creator: creator)
    end
    let(:notification) { create(:notification, :request_created, notifiable: bs_request) }

    before do
      render_inline(described_class.new(notification))
    end

    it "renders an avatar for the BsRequest's creator with the avatar title being the creator's real name" do
      expect(rendered_content).to have_selector('li.list-inline-item > img[title="Johnny Dupuis"]', count: 1)
    end

    it "renders an avatar for a group review with the avatar title being the group's title" do
      expect(rendered_content).to have_selector('li.list-inline-item > img[title="Canailles"]', count: 1)
    end

    it "renders an avatar for a user review with the avatar title being the user's real name" do
      expect(rendered_content).to have_selector('li.list-inline-item > img[title="Jane Doe"]', count: 1)
    end

    it "renders an avatar for a package review with the avatar title being the package's project and name" do
      expect(rendered_content).to have_selector('li.list-inline-item > span[title="Package project1/package1"]', count: 1)
    end

    it "renders an avatar for a project review with the avatar title being the project's name" do
      expect(rendered_content).to have_selector('li.list-inline-item > span[title="Project project2"]', count: 1)
    end
  end
end
