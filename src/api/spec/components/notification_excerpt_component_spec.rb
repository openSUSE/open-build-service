require 'rails_helper'

RSpec.describe NotificationExcerptComponent, type: :component do
  let(:user) { create(:user) }
  let(:notification_for_projects_comment) { create(:web_notification, :comment_for_project, notifiable: comment, subscriber: user) }

  context 'with short excerpt' do
    let(:comment) { create(:comment_project, body: Faker::Lorem.characters(number: 20)) }

    it do
      expect(render_inline(described_class.new(notification_for_projects_comment))).not_to have_text('...')
    end
  end

  context 'with long excerpt' do
    let(:comment) { create(:comment_project, body: Faker::Lorem.characters(number: 120)) }

    it do
      expect(render_inline(described_class.new(notification_for_projects_comment))).to have_text('...')
    end
  end
end
