# frozen_string_literal: true
require 'rails_helper'

RSpec.describe EventSubscription::GenerateHashForSubscriber do
  describe '#query' do
    include_context 'a user and subscriptions'

    let(:subscriber) { user }

    subject { EventSubscription::GenerateHashForSubscriber.new(subscriber).query }

    context 'with a user as the subscriber' do
      it 'includes the users subscriptions first' do
        subscriptions = subject[Event::CommentForProject]

        expect(subscriptions.count).to eq(3)
        expect(subscriptions).to include(user_subscription1, user_subscription2)
      end

      it 'includes the default subscriptions second' do
        subscriptions = subject[Event::CommentForRequest]

        expect(subscriptions.count).to eq(7)
        expect(subscriptions).to include(default_subscription3, default_subscription4)
      end

      it 'includes newly instantiated subscriptions third' do
        events = Event::Base.notification_events - [Event::CommentForProject, Event::CommentForRequest]

        events.each do |event_class|
          subject[event_class].each do |subscription|
            expect(subscription.persisted?).to be_falsey
            expect(subscription.subscriber).to eq(user)
            expect(subscription.eventtype).to eq(event_class.to_s)
            expect(subscription.channel).to eq('disabled')
          end
        end
      end
    end

    context 'with nil as the subscriber' do
      let(:subscriber) { nil }

      it 'includes the default subscriptions first' do
        expect(subject[Event::CommentForProject].count).to eq(3)
        expect(subject[Event::CommentForProject]).to include(default_subscription1, default_subscription2)

        expect(subject[Event::CommentForRequest].count).to eq(7)
        expect(subject[Event::CommentForRequest]).to include(default_subscription3, default_subscription4)
      end

      it 'includes newly instantiated subscriptions second' do
        events = Event::Base.notification_events - [Event::CommentForProject, Event::CommentForRequest]

        events.each do |event_class|
          subject[event_class].each do |subscription|
            expect(subscription.persisted?).to be_falsey
            expect(subscription.user).to be_nil
            expect(subscription.group).to be_nil
            expect(subscription.eventtype).to eq(event_class.to_s)
            expect(subscription.channel).to eq('disabled')
          end
        end
      end
    end
  end
end
