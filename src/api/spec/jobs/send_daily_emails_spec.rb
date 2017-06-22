require 'rails_helper'

RSpec.describe SendDailyEmails, type: :job do
  include ActiveJob::TestHelper

  describe '#perform' do
    before do
      ActionMailer::Base.deliveries = []
      # Needed for X-OBS-URL
      allow_any_instance_of(Configuration).to receive(:obs_url).and_return('https://build.example.com')
    end

    let!(:user1) { create(:confirmed_user) }
    let!(:user2) { create(:confirmed_user) }
    let!(:project) { create(:project) }

    let!(:subscription1) do
      create(:event_subscription, eventtype: 'Event::CommentForProject', receiver_role: 'all', user: user1, channel: :daily_email)
    end
    let!(:subscription2) do
      create(:event_subscription, eventtype: 'Event::CommentForProject', receiver_role: 'all', user: user2, channel: :daily_email)
    end

    let!(:event1) do
      Event::CommentForProject.create(project: project.name, commenters: [user1.id, user2.id], commenter: user2.id, comment_body: "Hey #{user1.login}, how are you?")
    end
    let!(:event2) do
      Event::CommentForProject.create(project: project.name, commenters: [user1.id, user2.id], commenter: user1.id, comment_body: "I'm good thanks how are you?")
    end
    let!(:event3) do
      Event::CommentForProject.create(project: project.name, commenters: [user1.id, user2.id],commenter: user2.id,comment_body: "I'm still waiting for these bloody daily emails to be finished!")
    end

    let!(:notification1) do
      Notifications::DailyEmailItem.create(
        subscriber: subscription1.subscriber,
        event_type: event1.eventtype,
        event_payload: event1.read_attribute(:payload),
        subscription_receiver_role: subscription1.receiver_role
      )
    end
    let!(:notification2) do
      Notifications::DailyEmailItem.create(
        subscriber: subscription2.subscriber,
        event_type: event2.eventtype,
        event_payload: event2.read_attribute(:payload),
        subscription_receiver_role: subscription2.receiver_role
      )
    end
    let!(:notification3) do
      Notifications::DailyEmailItem.create(
        subscriber: subscription1.subscriber,
        event_type: event3.eventtype,
        event_payload: event3.read_attribute(:payload),
        subscription_receiver_role: subscription1.receiver_role
      )
    end

    subject! { SendDailyEmails.new.perform }

    it { expect(ActionMailer::Base.deliveries.count).to eq(2) }
  end
end
