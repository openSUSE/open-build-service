RSpec.describe EventSubscription::ForRoleForm do
  describe '#call' do
    subject { EventSubscription::ForRoleForm.new(role, event_class, subscriber).call }

    include_context 'a user and subscriptions'

    let(:subscriber) { user }
    let(:channel) { subject.channels.first }
    let(:subscription) { channel.subscription }

    RSpec.shared_examples 'a channel with subscription' do |channel_name|
      it { expect(subject.channels.map(&:name)).to match_array(EventSubscription.without_disabled_or_internal_channels) }
      it { expect(channel.name).to eq(channel_name) }
      it { expect(subscription.eventtype).to eq(event_class.to_s) }
      it { expect(subscription.receiver_role).to eq(role) }
    end

    context 'with common subscription' do
      let(:role) { :maintainer }
      let(:event_class) { Event::CommentForProject }

      context 'with channel instant_email' do
        it_behaves_like 'a channel with subscription', 'instant_email'
        it { expect(subscription).to be_instant_email }
        it { expect(subscription).not_to be_new_record }
        it { expect(subscription).to eq(user_subscription2) }
        it { expect(subscription).to be_enabled }
      end

      context 'with channel web' do
        let(:channel) { subject.channels.second }
        let(:subscription) { channel.subscription }

        it_behaves_like 'a channel with subscription', 'web'
        it { expect(subscription).to be_web }
        it { expect(subscription).not_to be_new_record }
        it { expect(subscription).to eq(user_subscription3) }
        it { expect(subscription).to be_enabled }
      end

      context 'with channel rss' do
        let(:channel) { subject.channels.third }
        let(:subscription) { channel.subscription }

        it_behaves_like 'a channel with subscription', 'rss'
        it { expect(subscription).to be_new_record }
        it { expect(subscription).to be_rss }
        it { expect(subscription).not_to be_enabled }
      end
    end

    context 'with default subscription' do
      let(:role) { :source_maintainer }
      let(:event_class) { Event::CommentForRequest }

      it_behaves_like 'a channel with subscription', 'instant_email'
      it { expect(subscription).to eq(default_subscription3) }
    end

    context 'without subscription' do
      let(:role) { :commenter }
      let(:event_class) { Event::CommentForPackage }

      it_behaves_like 'a channel with subscription', 'instant_email'
      it { expect(subscription).to be_new_record }
      it { expect(subscription).to be_instant_email }
      it { expect(subscription).not_to be_enabled }
    end
  end
end
