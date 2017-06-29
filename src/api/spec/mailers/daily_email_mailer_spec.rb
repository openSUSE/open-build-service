require 'rails_helper'

RSpec.describe DailyEmailMailer do
  # Needed for X-OBS-URL
  before do
    allow_any_instance_of(Configuration).to receive(:obs_url).and_return('https://build.example.com')
  end

  let!(:user1) { create(:confirmed_user) }
  let!(:user2) { create(:confirmed_user) }

  let!(:subscription1) do
    create(:event_subscription, eventtype: 'Event::CommentForProject', receiver_role: 'all', user: user1, channel: :daily_email)
  end

  let!(:event1) do
    Event::CommentForProject.create(commenters: [user1.id, user2.id], commenter: user2.id, comment_body: "Hey #{user1.login}, how are you?")
  end
  let!(:event2) do
    Event::CommentForProject.create(commenters: [user1.id, user2.id],commenter: user2.id,comment_body: "I'm good thanks how are you?")
  end

  let!(:notification1) do
    Notification::DailyEmailItem.create(
      subscriber: subscription1.subscriber,
      event_type: event1.eventtype,
      event_payload: event1.read_attribute(:payload),
      subscription_receiver_role: subscription1.receiver_role
    )
  end
  let!(:notification2) do
    Notification::DailyEmailItem.create(
      subscriber: subscription1.subscriber,
      event_type: event2.eventtype,
      event_payload: event2.read_attribute(:payload),
      subscription_receiver_role: subscription1.receiver_role
    )
  end
  let(:notifications) { [notification1, notification2] }

  describe '#notifications' do
    subject! { DailyEmailMailer.notifications(user1, notifications).deliver_now }

    it 'gets delivered' do
      expect(ActionMailer::Base.deliveries).to include(subject)
    end

    it 'includes the messages from both events in html and text formats' do
      body_text = ActionMailer::Base.deliveries.first.text_part.body.raw_source
      expect(body_text).to include("Hey #{user1.login}, how are you?")
      expect(body_text).to include("I'm good thanks how are you?")

      body_html = ActionMailer::Base.deliveries.first.html_part.body.raw_source
      expect(body_html).to include("Hey #{user1.login}, how are you?")
      expect(body_html).to include("good thanks how are you?")
    end
  end
end
