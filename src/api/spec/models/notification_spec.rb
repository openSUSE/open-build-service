RSpec.describe Notification do
  let(:payload) { { comment: 'SuperFakeComment', requestid: 1 } }
  let(:delete_package_event) { Event::DeletePackage.new(payload) }

  describe '#event' do
    subject { create(:notification_for_package, :rss_notification, event_type: 'Event::DeletePackage', event_payload: payload).event }

    it { expect(subject.class).to eq(delete_package_event.class) }
    it { expect(subject.payload).to eq(delete_package_event.payload) }
  end

  describe 'relationship with users' do
    let(:regular_user) { create(:confirmed_user, login: 'foo') }
    let(:notification) { create(:notification_for_request, :rss_notification, subscriber: regular_user) }

    it { expect(regular_user.notifications).to include(notification) }
  end

  describe 'relationship with groups' do
    let(:test_group) { create(:group, title: 'my_test_group') }
    let(:notification) { create(:notification_for_request, :rss_notification, subscriber: test_group) }

    it { expect(test_group.notifications).to include(notification) }
  end

  describe '#user_active?' do
    subject { rss_notification.user_active? }

    let(:rss_notification) { create(:notification_for_request, :rss_notification, subscriber: test_user) }

    context 'when subscriber is away' do
      let(:test_user) { create(:dead_user, login: 'foo') }

      it { expect(subject).to be_falsey }
    end

    context 'when subscribe logged in recently' do
      let(:test_user) { create(:confirmed_user, login: 'foo') }

      it { expect(subject).to be_truthy }
    end
  end

  describe '#any_user_in_group_active?' do
    subject { rss_notification.any_user_in_group_active? }

    let(:rss_notification) { create(:notification_for_request, :rss_notification, subscriber: test_group) }
    let(:test_group) { create(:group) }

    before do
      test_group.add_user(test_user)
    end

    context 'no active user in the group' do
      let!(:test_user) { create(:dead_user, login: 'foo') }

      it { expect(subject).to be_falsey }
    end

    context 'active user in the group' do
      let!(:test_user) { create(:confirmed_user, login: 'foo') }

      it { expect(subject).to be_truthy }
    end
  end

  describe 'Instrumentation' do
    let!(:test_user) { create(:confirmed_user, login: 'foo') }
    let!(:web_notification) { create(:notification_for_request, :web_notification, subscriber: test_user) }

    before do
      allow(RabbitmqBus).to receive(:send_to_bus).with('metrics', 'notification,action=read value=1')
    end

    context 'if delivered change, we should track it' do
      before do
        web_notification.delivered = true
      end

      it do
        web_notification.save
        expect(RabbitmqBus).to have_received(:send_to_bus).with('metrics', 'notification,action=read value=1')
      end
    end

    context 'if delivered does not change, we should not track it' do
      before do
        web_notification.title = 'FOO FOO'
      end

      it do
        web_notification.save
        expect(RabbitmqBus).not_to have_received(:send_to_bus).with('metrics', 'notification,action=read value=1')
      end
    end
  end
end
