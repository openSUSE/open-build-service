require 'rails_helper'

RSpec.describe Webui::WatchedItemsController, type: :controller do
  describe '#toggle' do
    context 'when the user belongs to the beta group' do
      before do
        Flipper.enable(:new_watchlist, user)
      end

      context 'when the watched item is not already watched' do
        let(:user) { create(:confirmed_user) }
        let(:package) { create(:package) }

        before do
          login user
          put :toggle, params: { package: package, project: package.project }
        end

        it 'redirects back' do
          expect(response).to redirect_to(root_path)
        end

        it 'adds the watched item to the watchlist' do
          expect(user.watched_items.map(&:watchable)).to include(package)
        end

        it 'shows the flash with the success message' do
          expect(flash[:success]).to match('Added package to the watchlist')
        end
      end

      context 'when the watched item is already watched' do
        let(:user) { create(:confirmed_user) }
        let(:package) { create(:package) }

        before do
          login user
          user.watched_items.create(watchable: package)

          put :toggle, params: { package: package, project: package.project }
        end

        it 'redirects back' do
          expect(response).to redirect_to(root_path)
        end

        it 'removes the watched item from the watchlist' do
          expect(user.reload.watched_items.map(&:watchable)).to be_empty
        end

        it 'shows the flash with the success message' do
          expect(flash[:success]).to match('Removed package from the watchlist')
        end
      end
    end

    context 'when the user does not belongs to the beta group' do
      before do
        Flipper.disable(:new_watchlist, user)
      end

      context 'when the watched item is not already watched' do
        let(:user) { create(:confirmed_user) }
        let(:package) { create(:package) }

        before { login user }

        subject { put :toggle, params: { package: package, project: package.project } }

        it 'redirects back' do
          expect { subject }.to raise_error(NotFoundError)
        end
      end

      context 'when the watched item is already watched' do
        let(:user) { create(:confirmed_user) }
        let(:package) { create(:package) }

        before do
          login user
          user.watched_items.create(watchable: package)
        end

        subject { put :toggle, params: { package: package, project: package.project } }

        it 'redirects back' do
          expect { subject }.to raise_error(NotFoundError)
        end
      end
    end
  end
end
