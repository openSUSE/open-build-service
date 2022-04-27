require 'rails_helper'

RSpec.describe EventSubscription, type: :model do
  describe 'Instrumentation' do
    let(:user) { create(:confirmed_user, :with_home, login: 'cameron') }
    let(:token) { create(:workflow_token, user: user) }

    let!(:target_project) { create(:project, name: 'test-target-project:openSUSE:open-build-service:PR-4', maintainer: user) }
    let!(:target_package) { create(:package, name: 'test-target-package', project: target_project) }

    let(:event_type) { 'Event::BuildFail' }

    let(:event_subscription) { EventSubscription.create!(channel: 'scm', token: token, receiver_role: 'maintainer', eventtype: event_type, package: target_package) }

    before do
      allow(RabbitmqBus).to receive(:send_to_bus).with('metrics', "event_subscription.enabled,event_type=#{event_type},channel=scm value=1")
    end

    describe '#enabled was changed' do
      before do
        event_subscription.enabled = true
      end

      it do
        event_subscription.save
        expect(RabbitmqBus).to have_received(:send_to_bus).with('metrics', "event_subscription.enabled,event_type=#{event_type},channel=scm value=1")
      end
    end

    describe '#enabled wasnt changed' do
      before do
        event_subscription.channel = 'disabled'
      end

      it do
        event_subscription.save
        expect(RabbitmqBus).not_to have_received(:send_to_bus).with('metrics', "event_subscription.enabled,event_type=#{event_type},channel=scm value=1")
      end
    end
  end
end
