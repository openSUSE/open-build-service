require 'rails_helper'

RSpec.describe Notification do
  let(:payload) { { comment: 'SuperFakeComment', requestid: 1 } }
  let(:delete_package_event) { Event::DeletePackage.new(payload) }

  describe '.cleanup' do
    let!(:stale_notification) { create(:rss_notification, stale: true) }
    let!(:new_notification) { create(:rss_notification) }

    subject { Notification.cleanup }

    it { expect { subject }.to change(Notification, :count).by(-1) }
  end

  describe '#event' do
    subject { create(:rss_notification, event_type: 'Event::DeletePackage', event_payload: payload).event }

    it { expect(subject.class).to eq(delete_package_event.class) }
    it { expect(subject.payload).to eq(delete_package_event.payload) }
  end

  describe 'relationship with users' do
    let(:regular_user) { create(:confirmed_user, login: 'foo') }
    let(:notification) { create(:rss_notification, subscriber: regular_user) }

    it { expect(regular_user.notifications).to include(notification) }
  end

  describe 'relationship with groups' do
    let(:test_group) { create(:group, title: 'my_test_group') }
    let(:notification) { create(:rss_notification, subscriber: test_group) }

    it { expect(test_group.notifications).to include(notification) }
  end
end
