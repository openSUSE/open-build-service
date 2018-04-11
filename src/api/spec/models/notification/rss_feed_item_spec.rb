# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Notification::RssFeedItem do
  let(:payload) { { comment: 'SuperFakeComment', requestid: 1 } }
  let(:delete_package_event) { Event::DeletePackage.new(payload) }

  describe '.cleanup' do
    let(:user) { create(:confirmed_user) }
    let(:user2) { create(:confirmed_user) }
    let(:group) { create(:group, users: [user, user2]) }
    let(:unconfirmed_user) { create(:user) }
    let(:max_items_per_user) { Notification::RssFeedItem::MAX_ITEMS_PER_USER }
    let(:max_items_per_group) { Notification::RssFeedItem::MAX_ITEMS_PER_GROUP }
    let(:greater_than_max_items_per_user) { max_items_per_user + 3 }
    let(:greater_than_max_items_per_group) { max_items_per_group + 5 }

    context 'without any RSS items' do
      it { expect { Notification::RssFeedItem.cleanup }.not_to(change { Notification::RssFeedItem.count }) }
    end

    context 'with a single users' do
      context 'and not enough RSS items' do
        before do
          create_list(:rss_notification, max_items_per_user, subscriber: user)
        end

        it { expect { Notification::RssFeedItem.cleanup }.not_to(change { Notification::RssFeedItem.count }) }
      end

      context 'and enough RSS items' do
        context 'for an active user' do
          before do
            create_list(:rss_notification, greater_than_max_items_per_user, subscriber: user)
          end

          it { expect { Notification::RssFeedItem.cleanup }.to change { Notification::RssFeedItem.count }.by(-3) }
        end

        context 'for a non active user' do
          before do
            create_list(:rss_notification, greater_than_max_items_per_user, subscriber: unconfirmed_user)
          end

          it { expect { Notification::RssFeedItem.cleanup }.to change { Notification::RssFeedItem.count }.by(-greater_than_max_items_per_user) }
        end
      end
    end

    context 'with multiple users' do
      context 'all of them active' do
        before do
          create_list(:rss_notification, greater_than_max_items_per_user, subscriber: user)
          create_list(:rss_notification, greater_than_max_items_per_user, subscriber: user2)
        end

        it { expect { Notification::RssFeedItem.cleanup }.to change { user.rss_feed_items.count }.by(-3) }
        it { expect { Notification::RssFeedItem.cleanup }.to change { user2.rss_feed_items.count }.by(-3) }
      end

      context 'being a mixture of active and non active users' do
        before do
          create_list(:rss_notification, greater_than_max_items_per_user, subscriber: user)
          create_list(:rss_notification, greater_than_max_items_per_user, subscriber: unconfirmed_user)
        end

        it { expect { Notification::RssFeedItem.cleanup }.to change { user.rss_feed_items.count }.by(-3) }
        it { expect { Notification::RssFeedItem.cleanup }.to change { unconfirmed_user.rss_feed_items.count }.by(-greater_than_max_items_per_user) }
      end
    end

    context 'with users and group notifications' do
      before do
        create_list(:rss_notification, greater_than_max_items_per_user, subscriber: user)
        create_list(:rss_notification, greater_than_max_items_per_user, subscriber: user2)
        create_list(:rss_notification, greater_than_max_items_per_user, subscriber: unconfirmed_user)
        create_list(:rss_notification, greater_than_max_items_per_group, subscriber: group)
      end

      it { expect { Notification::RssFeedItem.cleanup }.to change { user.rss_feed_items.count }.by(-3) }
      it { expect { Notification::RssFeedItem.cleanup }.to change { user2.rss_feed_items.count }.by(-3) }
      it { expect { Notification::RssFeedItem.cleanup }.to change { group.rss_feed_items.count }.by(-5) }
      it { expect { Notification::RssFeedItem.cleanup }.to change { unconfirmed_user.rss_feed_items.count }.by(-greater_than_max_items_per_user) }
    end
  end
end
