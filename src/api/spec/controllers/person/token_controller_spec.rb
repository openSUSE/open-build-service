require 'rails_helper'

RSpec.describe Person::TokenController, vcr: false do
  let(:user) { create(:user_with_service_token) }
  let(:other_user) { create(:confirmed_user) }
  let(:admin_user) { create(:admin_user) }

  describe '#index' do
    context 'called by authorized user' do
      before do
        login user
        get :index, params: { login: user.login }, format: :xml
      end

      it { expect(response).to render_template(:index) }
      it { expect(response).to have_http_status(:success) }
      it { expect(assigns(:list)).to eq(user.service_tokens) }
    end

    context 'called by unauthorized user' do
      before do
        login other_user
        get :index, params: { login: user.login }, format: :xml
      end

      it { expect(response).not_to render_template(:index) }
      it { expect(response).to have_http_status(:forbidden) }
      it { expect(assigns(:list)).to be nil }
    end
  end

  describe '#create' do
    context 'called with no project and package parameter' do
      before do
        login user
      end

      subject { post :create, params: { login: user.login }, format: :xml }

      it 'creates a global token' do
        expect { subject }.to change { user.service_tokens.count }.by(+1)
        expect(response).to have_http_status(:success)
      end
    end

    context 'called with project and package parameter' do
      let!(:package) { create(:package, project: user.home_project) }

      before do
        login user
        post :create, params: { login: user.login, package: package, project: package.project }, format: :xml
      end

      it { expect(response).to have_http_status(:success) }
      it { expect(response).to render_template(:create) }
      it { expect(user.service_tokens.where(package: package)).to exist }
      it { expect(assigns(:token)).to eq(package.token) }
    end

    context 'called by unauthorized user' do
      before do
        login other_user
      end

      subject { post :create, params: { login: user.login }, format: :xml }

      it 'permits access' do
        expect { subject }.not_to(change { user.service_tokens.count })
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe '#delete' do
    let!(:token) { create(:service_token, user: user) }

    subject { delete :delete, params: { login: user.login, id: token.id }, format: :xml }

    context 'called by authorized user' do
      before do
        login user
      end

      it 'deletes the token' do
        expect { subject }.to change { user.service_tokens.count }.by(-1)
        expect(response).to have_http_status(:success)
      end
    end

    context 'requesting deletion of a non-existant token' do
      before do
        login user
        delete :delete, params: { login: user.login, id: 42 }, format: :xml
      end

      it { expect(response).to have_http_status(:not_found) }
    end

    context 'called by unauthorized user' do
      before do
        login other_user
      end

      it 'does not delete the token' do
        expect { subject }.not_to(change { user.service_tokens.count })
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
