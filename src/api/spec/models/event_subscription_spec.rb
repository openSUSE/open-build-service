require 'rails_helper'

RSpec.describe EventSubscription, type: :model do
  describe 'Instrumentation' do
    let(:user) { create(:confirmed_user, :with_home, login: 'cameron') }
    let(:token) { create(:workflow_token, user: user) }

    let(:channel) { 'scm' }
    let!(:target_project) { create(:project, name: 'test-target-project:openSUSE:open-build-service:PR-4', maintainer: user) }
    let!(:target_package) { create(:package, name: 'test-target-package', project: target_project) }

    let(:event_type) { 'Event::BuildFail' }

    let(:event_enabled) { true }

    let!(:event_subscription) do
      EventSubscription.create!(channel: channel, token: token, receiver_role: 'maintainer', eventtype: event_type, package: target_package, user: user, enabled: event_enabled)
    end

    let(:expected_instrumentation) { "event_subscription.event,event_type=#{event_type},receiver_role=maintainer,enabled=#{event_enabled},user=#{user},channel=#{channel} value=1" }

    before do
      allow(RabbitmqBus).to receive(:send_to_bus).with('metrics', expected_instrumentation)
    end

    describe '#enabled was changed' do
      before do
        event_subscription.enabled = true
      end

      it do
        event_subscription.save
        expect(RabbitmqBus).to have_received(:send_to_bus).with('metrics', expected_instrumentation)
      end
    end

    describe '#enabled wasnt changed' do
      let(:channel) { 'disabled' }
      let(:event_enabled) { false }

      before do
        event_subscription.channel = channel
      end

      it do
        event_subscription.save
        expect(RabbitmqBus).to have_received(:send_to_bus).with('metrics', expected_instrumentation)
      end
    end
  end
end
