require "rails_helper"

RSpec.describe Notifications::RssFeedItem do
  describe '.cleanup' do
    let(:user) { create(:confirmed_user) }
    let(:user2) { create(:confirmed_user) }
    let(:group) { create(:group, users: [user, user2]) }
    let(:unconfirmed_user) { create(:user) }
    let(:max_items_per_user) { Notifications::RssFeedItem::MAX_ITEMS_PER_USER }
    let(:max_items_per_group) { Notifications::RssFeedItem::MAX_ITEMS_PER_GROUP }
    let(:greater_than_max_items_per_user) { max_items_per_user + 3 }
    let(:greater_than_max_items_per_group) { max_items_per_group + 5 }

    context 'without any RSS items' do
      it { expect { Notifications::RssFeedItem.cleanup }.not_to change { Notifications::RssFeedItem.count } }
    end

    context 'with a single users' do
      context 'and not enough RSS items' do
        before do
          create_list(:rss_notification, max_items_per_user, user: user)
        end

        it { expect { Notifications::RssFeedItem.cleanup }.not_to change { Notifications::RssFeedItem.count } }
      end

      context 'and enough RSS items' do
        context 'for an active user' do
          before do
            create_list(:rss_notification, greater_than_max_items_per_user, user: user)
          end

          it { expect { Notifications::RssFeedItem.cleanup }.to change { Notifications::RssFeedItem.count }.by(-3) }
        end

        context 'for a non active user' do
          before do
            create_list(:rss_notification, greater_than_max_items_per_user, user: unconfirmed_user)
          end

          it { expect { Notifications::RssFeedItem.cleanup }.to change { Notifications::RssFeedItem.count }.by(-greater_than_max_items_per_user) }
        end
      end
    end

    context 'with multiple users' do
      context 'all of them active' do
        before do
          create_list(:rss_notification, greater_than_max_items_per_user, user: user)
          create_list(:rss_notification, greater_than_max_items_per_user, user: user2)
        end

        it { expect { Notifications::RssFeedItem.cleanup }.to change { user.rss_feed_items.count }.by(-3) }
        it { expect { Notifications::RssFeedItem.cleanup }.to change { user2.rss_feed_items.count }.by(-3) }
      end

      context 'being a mixture of active and non active users' do
        before do
          create_list(:rss_notification, greater_than_max_items_per_user, user: user)
          create_list(:rss_notification, greater_than_max_items_per_user, user: unconfirmed_user)
        end

        it { expect { Notifications::RssFeedItem.cleanup }.to change { user.rss_feed_items.count }.by(-3) }
        it { expect { Notifications::RssFeedItem.cleanup }.to change { unconfirmed_user.rss_feed_items.count }.by(-greater_than_max_items_per_user) }
      end
    end

    context 'with users and group notifications' do
      before do
        create_list(:rss_notification, greater_than_max_items_per_user, user: user)
        create_list(:rss_notification, greater_than_max_items_per_user, user: user2)
        create_list(:rss_notification, greater_than_max_items_per_user, user: unconfirmed_user)
        create_list(:rss_notification, greater_than_max_items_per_group, group: group)
      end

      it { expect { Notifications::RssFeedItem.cleanup }.to change { user.rss_feed_items.count }.by(-3) }
      it { expect { Notifications::RssFeedItem.cleanup }.to change { user2.rss_feed_items.count }.by(-3) }
      it { expect { Notifications::RssFeedItem.cleanup }.to change { group.rss_feed_items.count }.by(-5) }
      it { expect { Notifications::RssFeedItem.cleanup }.to change { unconfirmed_user.rss_feed_items.count }.by(-greater_than_max_items_per_user) }
    end
  end
end
