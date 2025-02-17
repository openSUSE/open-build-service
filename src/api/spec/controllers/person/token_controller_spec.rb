RSpec.describe Person::TokenController do
  let(:user) { create(:user_with_service_token, :with_home) }
  let(:other_user) { create(:confirmed_user) }

  describe '#index' do
    context 'called by authorized user' do
      before do
        login user
        get :index, params: { login: user.login }, format: :xml
      end

      it { expect(response).to render_template(:index) }
      it { expect(response).to have_http_status(:success) }
      it { expect(assigns(:list)).to eq(user.tokens) }
    end

    context 'called by unauthorized user' do
      before do
        login other_user
        get :index, params: { login: user.login }, format: :xml
      end

      it { expect(response).not_to render_template(:index) }
      it { expect(response).to have_http_status(:forbidden) }
      it { expect(assigns(:list)).to be_nil }
    end

    context 'called for a user that does not exist' do
      before do
        login user
        get :index, params: { login: 'non-existent-user' }, format: :xml
      end

      it { expect(response).not_to render_template(:index) }
      it { expect(response).to have_http_status(:forbidden) }
      it { expect(assigns(:list)).to be_nil }
    end
  end

  describe '#create' do
    context 'called with no project and package parameter' do
      subject { post :create, params: { login: user.login, operation: 'rebuild' }, format: :xml }

      before do
        login user
      end

      it 'creates a global token' do
        expect { subject }.to change { user.tokens.count }.by(+1)
        expect(response).to have_http_status(:success)
      end
    end

    context 'called with only project parameter' do
      subject { post :create, params: { login: user.login, project: user.home_project, operation: 'rebuild' }, format: :xml }

      before do
        login user
      end

      it 'creates a global token' do
        expect { subject }.to change { user.tokens.count }.by(1)
        expect(response).to have_http_status(:success)
      end
    end

    context 'called with only package parameter' do
      subject { post :create, params: { login: user.login, package: 'test', operation: 'create' }, format: :xml }

      before do
        login user
      end

      it 'does not create a token' do
        expect { subject }.not_to(change { user.tokens.count })
        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'called with project and package parameter' do
      subject { post :create, params: { login: user.login, package: package, project: package.project, operation: 'runservice' }, format: :xml }

      let!(:package) { create(:package, project: user.home_project) }

      before do
        login user
      end

      it { expect(response).to have_http_status(:success) }

      it 'creates a token' do
        expect { subject }.to change { user.tokens.count }.by(+1)
      end
    end

    context 'operation is workflow' do
      subject { post :create, params: { login: user.login, operation: 'workflow', scm_token: '123456789' }, format: :xml }

      let!(:package) { create(:package, project: user.home_project) }

      before do
        login user
      end

      it { expect(response).to have_http_status(:success) }
      it { expect { subject }.to change { user.tokens.count }.by(+1) }
    end

    context 'called by unauthorized user' do
      subject { post :create, params: { login: user.login }, format: :xml }

      before do
        login other_user
      end

      it 'permits access' do
        expect { subject }.not_to(change { user.tokens.count })
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe '#delete' do
    let!(:token) { create(:service_token, executor: user) }

    context 'requesting deletion of an existent token as an authorized user' do
      subject { delete :delete, params: { login: user.login, id: token.id }, format: :xml }

      before do
        login user
      end

      it 'deletes the token' do
        expect { subject }.to change { user.tokens.count }.by(-1)
        expect(response).to have_http_status(:success)
      end
    end

    context 'requesting deletion of an existent token as an unauthorized user' do
      subject { delete :delete, params: { login: user.login, id: token.id }, format: :xml }

      before do
        login other_user
      end

      it 'does not delete the token' do
        expect { subject }.not_to(change { user.tokens.count })
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'requesting deletion of a non-existent token' do
      # Prevent potential flickering by adding 1 to the id of the last token
      subject { delete :delete, params: { login: user.login, id: Token.last.id + 1 }, format: :xml }

      before do
        login user
      end

      it 'does nothing' do
        expect { subject }.not_to(change { user.tokens.count })
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe '#update' do
    subject { put :update, params: { login: user.login, id: params_id }, format: :xml, body: xml }

    let(:token) { create(:service_token, executor: user) }
    let(:params_id) { token.id }
    let(:xml) { '<token enabled="false"></token>' }

    context 'authorized user with one of their tokens' do
      render_views

      before do
        login user
      end

      it 'updates the token' do
        expect { subject }.to change { token.reload.enabled }.from(true).to(false)
        expect(response).to have_http_status(:success)
      end
    end

    context 'unauthorized user' do
      before do
        login other_user
      end

      it 'does not update the token' do
        expect { subject }.not_to(change { token.reload.enabled })
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'non-existent token' do
      let(:params_id) { Token.last.id + 100 }

      before do
        login user
      end

      it 'does not update the token' do
        expect { subject }.not_to(change { token.reload.enabled })
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
