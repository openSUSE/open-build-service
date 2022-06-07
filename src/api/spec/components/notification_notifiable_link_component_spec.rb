require 'rails_helper'

RSpec.describe NotificationNotifiableLinkComponent, type: :component do
  context 'for a BsRequest notification with multiple actions' do
    let(:bs_request) { create(:bs_request_with_submit_action, number: 456_345) }
    let(:notification) { create(:notification, :request_state_change, notifiable: bs_request) }

    before do
      # Extra BsRequestAction
      bs_request.bs_request_actions << create(:bs_request_action_add_maintainer_role)

      render_inline(described_class.new(notification))
    end

    it 'renders a link to the BsRequest with a generic text and its number' do
      expect(rendered_content).to have_link('Multiple Actions Request #456345', href: "/request/show/456345?notification_id=#{notification.id}")
    end
  end

  context 'for a BsRequest notification with the event Event::RequestStatechange' do
    let(:bs_request) { create(:bs_request_with_submit_action, number: 123_456) }
    let(:notification) { create(:notification, :request_state_change, notifiable: bs_request) }

    before do
      render_inline(described_class.new(notification))
    end

    it 'renders a link to the BsRequest with the text containing its action and number' do
      expect(rendered_content).to have_link('Submit Request #123456', href: "/request/show/123456?notification_id=#{notification.id}")
    end
  end

  context 'for a BsRequest notification with the event Event::RequestCreate' do
    let(:bs_request) { create(:add_role_request, number: 123_789) }
    let(:notification) { create(:notification, :request_created, notifiable: bs_request) }

    before do
      render_inline(described_class.new(notification))
    end

    it 'renders a link to the BsRequest with the text containing its action and number' do
      expect(rendered_content).to have_link('Add Role Request #123789', href: "/request/show/123789?notification_id=#{notification.id}")
    end
  end

  context 'for a BsRequest notification with the event Event::ReviewWanted' do
    let(:bs_request) { create(:delete_bs_request, number: 123_670) }
    let(:notification) { create(:notification, :review_wanted, notifiable: bs_request) }

    before do
      render_inline(described_class.new(notification))
    end

    it 'renders a link to the BsRequest with the text containing its action and number' do
      expect(rendered_content).to have_link('Delete Request #123670', href: "/request/show/123670?notification_id=#{notification.id}")
    end
  end

  context 'for a comment notification with the event Event::CommentForRequest' do
    let(:bs_request) { create(:delete_bs_request, number: 123_671) }
    let(:comment) { create(:comment, commentable: bs_request) }
    let(:notification) { create(:notification, :comment_for_request, notifiable: comment) }

    before do
      render_inline(described_class.new(notification))
    end

    it "renders a link to the comment's BsRequest with the text containing its action and number" do
      expect(rendered_content).to have_link('Comment on Delete Request #123671', href: "/request/show/123671?notification_id=#{notification.id}#comments-list")
    end
  end

  context 'for a comment notification with the event Event::CommentForProject' do
    let(:project) { create(:project, name: 'projet_de_societe') }
    let(:comment) { create(:comment, commentable: project) }
    let(:notification) { create(:notification, :comment_for_project, notifiable: comment) }

    before do
      render_inline(described_class.new(notification))
    end

    it "renders a link to the comment's project" do
      expect(rendered_content).to have_link('Comment on Project', href: "/project/show/projet_de_societe?notification_id=#{notification.id}#comments-list")
    end
  end

  context 'for a comment notification with the event Event::CommentForPackage' do
    let(:project) { create(:project, name: 'projet_de_societe') }
    let(:package) { create(:package, project: project, name: 'oui') }
    let(:comment) { create(:comment, commentable: package) }
    let(:notification) { create(:notification, :comment_for_package, notifiable: comment) }

    before do
      render_inline(described_class.new(notification))
    end

    it "renders a link to the comment's package" do
      expect(rendered_content).to have_link('Comment on Package', href: "/package/show/projet_de_societe/oui?notification_id=#{notification.id}#comments-list")
    end
  end
end
