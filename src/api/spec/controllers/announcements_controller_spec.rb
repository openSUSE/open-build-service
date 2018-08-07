require 'rails_helper'

RSpec.describe AnnouncementsController, type: :controller do
  let(:valid_attributes) { attributes_for(:announcement) }
  let(:announcement) { create(:announcement) }
  let(:invalid_attributes) { { fake: 'blah' } }
  let(:admin) { create(:admin_user, login: 'admin') }

  before do
    login admin
  end

  describe 'GET #index' do
    it 'returns a success response' do
      announcement
      get :index, params: {}
      expect(response).to have_http_status(:success)
    end
  end

  describe 'GET #show' do
    it 'returns a success response' do
      get :show, params: { id: announcement.to_param }
      expect(response).to have_http_status(:success)
    end
  end

  describe 'POST #create' do
    context 'with valid params' do
      it 'creates a new Announcement' do
        expect do
          post :create, params: valid_attributes
        end.to change(Announcement, :count).by(1)
      end

      it 'redirects to the created announcement' do
        post :create, params: valid_attributes
        expect(response).to redirect_to(Announcement.last)
      end
    end

    context 'with invalid params' do
      it "returns a success response (i.e. to display the 'new' template)" do
        post :create, params: invalid_attributes
        expect(response).not_to have_http_status(:success)
      end
    end
  end

  describe 'PUT #update' do
    context 'with valid params' do
      let(:new_attributes) { { title: 'blah blah', content: 'foo' } }

      it 'updates the requested announcement' do
        put :update, params: { id: announcement.to_param }.merge(new_attributes)
        announcement.reload
        expect(announcement.title).to eq('blah blah')
        expect(response).to redirect_to(announcement)
      end

      it 'redirects to the announcement' do
        put :update, params: { id: announcement.to_param, announcement: valid_attributes }
        expect(response).to redirect_to(announcement)
      end
    end

    context 'with invalid params' do
      it "returns a success response (i.e. to display the 'edit' template)" do
        put :update, params: { id: announcement.to_param, announcement: invalid_attributes }
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe 'DELETE #destroy' do
    let!(:announcement) { create(:announcement) }

    it 'destroys the requested announcement' do
      expect do
        delete :destroy, params: { id: announcement.to_param }
      end.to change(Announcement, :count).by(-1)
    end

    it 'redirects to the announcements list' do
      delete :destroy, params: { id: announcement.to_param }
      expect(response).to redirect_to(announcements_url)
    end
  end
end
