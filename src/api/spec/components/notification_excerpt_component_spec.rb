require 'rails_helper'

RSpec.describe NotificationExcerptComponent, type: :component do
  let(:user) { create(:user) }

  context 'notification for a BsRequest without a description' do
    let(:bs_request) { create(:bs_request_with_submit_action, description: nil) }
    let(:notification) { create(:web_notification, :request_created, notifiable: bs_request, subscriber: user) }

    it do
      expect(render_inline(described_class.new(notification.notifiable))).to have_selector('p', text: '')
    end
  end

  context 'notification for a short comment' do
    let(:comment) { create(:comment_project, body: 'Nice project!') }
    let(:notification) { create(:web_notification, :comment_for_project, notifiable: comment, subscriber: user) }

    it do
      expect(render_inline(described_class.new(notification.notifiable))).to have_selector('p', text: 'Nice project!')
    end
  end

  context 'notification for a long comment' do
    let(:comment) { create(:comment_project, body: Faker::Lorem.characters(number: 120)) }
    let(:notification) { create(:web_notification, :comment_for_project, notifiable: comment, subscriber: user) }

    it do
      expect(render_inline(described_class.new(notification.notifiable))).to have_text('...')
    end
  end
end
