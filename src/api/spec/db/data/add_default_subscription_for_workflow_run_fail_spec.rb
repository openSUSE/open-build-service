# frozen_string_literal: true

require Rails.root.join('db/data/20251201183809_add_default_subscription_for_workflow_run_fail.rb')

RSpec.describe AddDefaultSubscriptionForWorkflowRunFail, type: :migration do
  describe 'up' do
    subject { described_class.new.up }

    it 'creates default subscriptions for Event::WorkflowRunFail' do
      expect { subject }.to change(EventSubscription, :count).by(4)
    end

    context 'after migration' do
      before { subject }

      it 'creates token_executor subscription with instant_email channel' do
        subscription = EventSubscription.find_by(
          eventtype: 'Event::WorkflowRunFail',
          receiver_role: 'token_executor',
          user_id: nil,
          group_id: nil,
          channel: :instant_email
        )
        expect(subscription).to be_present
        expect(subscription).to be_enabled
      end

      it 'creates token_executor subscription with web channel' do
        subscription = EventSubscription.find_by(
          eventtype: 'Event::WorkflowRunFail',
          receiver_role: 'token_executor',
          user_id: nil,
          group_id: nil,
          channel: :web
        )
        expect(subscription).to be_present
        expect(subscription).to be_enabled
      end

      it 'creates token_member subscription with instant_email channel' do
        subscription = EventSubscription.find_by(
          eventtype: 'Event::WorkflowRunFail',
          receiver_role: 'token_member',
          user_id: nil,
          group_id: nil,
          channel: :instant_email
        )
        expect(subscription).to be_present
        expect(subscription).to be_enabled
      end

      it 'creates token_member subscription with web channel' do
        subscription = EventSubscription.find_by(
          eventtype: 'Event::WorkflowRunFail',
          receiver_role: 'token_member',
          user_id: nil,
          group_id: nil,
          channel: :web
        )
        expect(subscription).to be_present
        expect(subscription).to be_enabled
      end
    end

    context 'when subscriptions already exist' do
      before do
        EventSubscription.create!(
          eventtype: 'Event::WorkflowRunFail',
          receiver_role: 'token_executor',
          user_id: nil,
          group_id: nil,
          channel: :instant_email,
          enabled: false
        )
      end

      it 'does not create duplicate subscriptions' do
        expect { subject }.to change(EventSubscription, :count).by(3)
      end

      it 'does not modify existing subscriptions' do
        subject
        subscription = EventSubscription.find_by(
          eventtype: 'Event::WorkflowRunFail',
          receiver_role: 'token_executor',
          channel: :instant_email
        )
        expect(subscription.enabled).to be false
      end
    end
  end

  describe 'down' do
    subject { described_class.new.down }

    before do
      described_class.new.up
    end

    it 'removes all default subscriptions for Event::WorkflowRunFail' do
      expect { subject }.to change(EventSubscription, :count).by(-4)
    end

    it 'only removes default subscriptions, not user-specific ones' do
      user = create(:confirmed_user)
      user_subscription = EventSubscription.create!(
        eventtype: 'Event::WorkflowRunFail',
        receiver_role: 'token_executor',
        user: user,
        channel: :web,
        enabled: true
      )

      subject

      expect(EventSubscription.exists?(user_subscription.id)).to be true
    end
  end
end
