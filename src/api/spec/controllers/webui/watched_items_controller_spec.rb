require 'rails_helper'

RSpec.describe Webui::WatchedItemsController do
  describe '#toggle_watched_item' do
    context 'when the package is not already watched' do
      let(:user) { create(:confirmed_user) }
      let(:package) { create(:package) }

      before do
        login user
        put :toggle_watched_item, params: { package_name: package, project_name: package.project }, xhr: true
      end

      it 'adds the package to the watchlist' do
        expect(user.watched_items).to exist(watchable: package)
      end
    end

    context 'when the request is not already watched' do
      let(:user) { create(:confirmed_user) }
      let(:bs_request) { create(:bs_request_with_submit_action) }

      before do
        login user
        put :toggle_watched_item, params: { number: bs_request.number }, xhr: true
      end

      it 'adds the request to the watchlist' do
        expect(user.watched_items).to exist(watchable: bs_request)
      end
    end

    context 'when the item is already watched' do
      let(:user) { create(:confirmed_user) }
      let(:package) { create(:package) }

      before do
        login user
        user.watched_items.create(watchable: package)
        put :toggle_watched_item, params: { package_name: package, project_name: package.project }, xhr: true
      end

      it 'removes the item from the watchlist' do
        expect(user.watched_items).not_to exist(watchable: package)
      end
    end
  end
end
