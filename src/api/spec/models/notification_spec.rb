require 'rails_helper'

RSpec.describe Notification do
  let(:payload) { { comment: 'SuperFakeComment', requestid: 1 } }
  let(:delete_package_event) { Event::DeletePackage.new(payload) }

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

  describe '#user_active?' do
    let(:rss_notification) { create(:rss_notification, subscriber: test_user) }

    subject { rss_notification.user_active? }

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
    let(:rss_notification) { create(:rss_notification, subscriber: test_group) }
    let(:test_group) { create(:group) }

    subject { rss_notification.any_user_in_group_active? }

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
end
