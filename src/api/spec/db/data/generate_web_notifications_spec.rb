require 'rails_helper'
require Rails.root.join('db/data/20200424080753_generate_web_notifications.rb')

RSpec.describe GenerateWebNotifications, type: :migration do
  describe 'up' do
    let(:owner) { create(:confirmed_user, login: 'bob') }
    let(:requester) { create(:confirmed_user, login: 'ann') }
    let!(:rss_notifications) { create_list(:rss_notification, 5, subscriber: owner) }
    let!(:event_subscription_1) { create(:event_subscription_comment_for_project, user: owner) }
    let!(:event_subscription_2) { create(:event_subscription_comment_for_project, user: owner, receiver_role: 'maintainer') }
    let!(:event_subscription_3) { create(:event_subscription_comment_for_project, user: owner, receiver_role: 'bugowner') }
    let!(:disabled_event_for_web_and_rss) { create(:event_subscription, eventtype: 'Event::BuildFail', user: owner, receiver_role: 'maintainer') }
    let!(:default_subscription) { create(:event_subscription_comment_for_project_without_subscriber, receiver_role: 'bugowner') }
    let!(:default_subscription_1) { create(:event_subscription_comment_for_project_without_subscriber, receiver_role: 'watcher') }
    let!(:default_subscription_2) do
      create(:event_subscription_comment_for_project_without_subscriber,
             receiver_role: 'maintainer',
             channel: :disabled,
             enabled: false)
    end

    subject { GenerateWebNotifications.new.up }

    it { expect { subject }.to change(EventSubscription, :count).from(7).to(14) }

    context 'check notification data' do
      before do
        subject
      end

      it { expect(Notification.pluck(:web)).to be_none(false) }
      it { expect(Notification.pluck(:rss)).to be_none(false) }
    end

    context 'check user subscriptions' do
      before do
        subject
      end

      it { expect(owner.event_subscriptions.where(channel: :rss)).to be_empty }
      it { expect(owner.event_subscriptions.where(channel: :web)).not_to be_empty }
      it { expect(owner.event_subscriptions.where(channel: :web).count).to eq(3) }
      it { expect(owner.event_subscriptions.where(eventtype: 'Event::BuildFail').count).to eq(1) }
    end

    context 'check default subscriptions' do
      before do
        subject
      end

      it { expect(EventSubscription.defaults.where(channel: :rss)).not_to be_empty }
      it { expect(EventSubscription.defaults.where(channel: :rss).count).to be(2) }
      it { expect(EventSubscription.defaults.where(channel: :web)).not_to be_empty }
      it { expect(EventSubscription.defaults.where(channel: :web).count).to be(2) }
      it { expect(EventSubscription.defaults.find_by(receiver_role: 'maintainer')).to be_instant_email }
      it { expect(EventSubscription.defaults.find_by(receiver_role: 'maintainer')).not_to be_enabled }
    end
  end
end
