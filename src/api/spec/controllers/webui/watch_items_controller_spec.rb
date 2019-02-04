require 'rails_helper'

RSpec.describe Webui::WatchItemsController, type: :controller do
  describe 'POST create' do
    let(:user) { create(:confirmed_user) }
    let(:project) { create(:project) }

    describe 'Add a project to the watchlist' do
      before do
        login user
        post :create, format: :json, params: { item_id: project.id, item_type: 'project' }
      end

      it {
        # TODO: Check what fields we need in the JS watchlist
        expect(JSON.parse(response.body)[0]['item_type']).to eq(project.class.name)
        expect(JSON.parse(response.body).size).to be 1
        expect(user.watch_items.size).to be 1
      }
    end

    describe 'Add the same project twice to the watchlist' do
      before do
        login user
        post :create, format: :json, params: { item_id: project.id, item_type: 'project' }
        post :create, format: :json, params: { item_id: project.id, item_type: 'project' }
      end

      it { expect(JSON.parse(response.body)['error']).to include 'has already been taken' }
      it { expect(JSON.parse(response.body)['status']).to include 'unprocessable_entity' }
    end
  end

  describe 'DELETE destroy' do
    let(:user) { create(:confirmed_user) }
    let(:project) { create(:project) }
    let(:another_project) { create(:project) }

    describe 'Remove a project to the watchlist' do
      before do
        login user
        watch_item = create(:watch_item, user: user, item: project)
        delete :destroy, format: :json, params: { id: watch_item.id }
      end

      it {
        # TODO: Check what fields we need in the JS watchlist
        expect(JSON.parse(response.body).size).to be 0
      }
    end

    describe 'Try to remove a project that is not in the watchlist' do
      before do
        login user
        delete :destroy, format: :json, params: { item_id: another_project.id, item_type: 'project' }
      end

      it { expect(JSON.parse(response.body)['errorcode']).to include 'not_found' }
      it { expect(JSON.parse(response.body)['summary']).to include "Couldn't find WatchItem without an ID" }
    end
  end
end
