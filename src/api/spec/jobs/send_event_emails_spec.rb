require 'rails_helper'

RSpec.describe SendEventEmails, type: :job do
  include ActiveJob::TestHelper

  describe '#perform' do
    before do
      ActionMailer::Base.deliveries = []
      # Needed for X-OBS-URL
      allow_any_instance_of(Configuration).to receive(:obs_url).and_return('https://build.example.com')
    end

    let!(:user) { create(:confirmed_user) }
    let!(:comment_author) { create(:confirmed_user) }
    let!(:group) { create(:group) }

    let!(:comment) { create(:comment_project, body: "Hey @#{user.login} how are things?", user: comment_author) }

    context 'with no errors being raised' do
      let!(:subscription1) { create(:event_subscription_comment_for_project, receiver_role: 'all', user: user) }
      let!(:subscription2) { create(:event_subscription_comment_for_project, receiver_role: 'all', user: nil, group: group) }
      let!(:subscription3) { create(:event_subscription_comment_for_project, receiver_role: 'all', user: comment_author) }

      subject! { SendEventEmails.new.perform }

      it 'sends an email to the subscribers' do
        email = ActionMailer::Base.deliveries.first

        expect(email.to).to match_array([user.email, group.email])
        expect(email.subject).to include('New comment')
      end

      it "creates an rss notification for user's email" do
        notification = Notification.find_by(subscriber: user)

        expect(notification.type).to eq('Notification::RssFeedItem')
        expect(notification.event_type).to eq('Event::CommentForProject')
        expect(notification.event_payload['comment_body']).to include('how are things?')
        expect(notification.subscription_receiver_role).to eq('all')
        expect(notification.delivered).to be_falsey
      end

      it "creates an rss notification for group's email" do
        notification = Notification::RssFeedItem.find_by(subscriber: group)

        expect(notification.type).to eq('Notification::RssFeedItem')
        expect(notification.event_type).to eq('Event::CommentForProject')
        expect(notification.event_payload['comment_body']).to include('how are things?')
        expect(notification.subscription_receiver_role).to eq('all')
        expect(notification.delivered).to be_falsey
      end

      it 'only creates two notifications' do
        expect(Notification.count).to eq(2)
      end
    end

    context 'with an error being raised' do
      let!(:subscription1) { create(:event_subscription_comment_for_project, receiver_role: 'all', user: user) }
      let!(:subscription2) { create(:event_subscription_comment_for_project, receiver_role: 'all', user: nil, group: group) }
      let!(:subscription3) { create(:event_subscription_comment_for_project, receiver_role: 'all', user: comment_author) }

      before do
        allow(EventMailer).to receive(:event).and_raise(StandardError)
        allow(Airbrake).to receive(:notify)
      end

      subject! { SendEventEmails.new.perform }

      it 'updates the event mails_sent = true' do
        event = Event::CommentForProject.first
        expect(event.mails_sent).to be_truthy
      end

      it 'notifies airbrake' do
        expect(Airbrake).to have_received(:notify)
      end
    end

    context 'with no subscriptions for the event' do
      subject! { SendEventEmails.new.perform }

      it 'updates the event mails_sent = true' do
        event = Event::CommentForProject.first
        expect(event.mails_sent).to be_truthy
      end

      it 'sends no emails' do
        expect(ActionMailer::Base.deliveries.count).to eq(0)
      end
    end
  end
end
