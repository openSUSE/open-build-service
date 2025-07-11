RSpec.describe Person::TokenController do
  let(:user) { create(:confirmed_user, :with_home) }

  describe '#create' do
    subject { post :create, params: params, format: :xml }

    let(:description) { Faker::Lorem.sentence }
    let(:params) { { login: user.login, description: description } }

    before do
      login user
    end

    it { expect { subject }.to change { user.tokens.count }.by(+1) }

    context 'with project parameter' do
      let(:params) { { login: user.login, project: user.home_project, description: description } }

      it 'creates a global token' do
        expect { subject }.to change { user.tokens.count }.by(+1)
        expect(user.tokens.last.slice(:package_id, :description)).to eq({ description: description, package_id: nil }.with_indifferent_access)
      end
    end

    context 'with package parameter' do
      let(:params) { { login: user.login, description: description, package: 'test' } }

      it 'creates a global token' do
        expect { subject }.to change { user.tokens.count }.by(+1)
        expect(user.tokens.last.slice(:package_id, :description)).to eq({ description: description, package_id: nil }.with_indifferent_access)
      end
    end

    context 'with project and package parameter' do
      let!(:package) { create(:package, project: user.home_project) }
      let(:params) { { login: user.login, description: description, project: package.project, package: package } }

      it 'creates a token' do
        expect { subject }.to change { user.tokens.count }.by(+1)
        expect(user.tokens.last.slice(:package_id, :description)).to eq({ description: description, package_id: package.id }.with_indifferent_access)
      end
    end
  end

  describe '#destroy' do
    subject { delete :destroy, params: { login: user.login, id: token.id }, format: :xml }

    let!(:token) { create(:service_token, executor: user) }

    before do
      login user
    end

    it 'deletes the token' do
      expect { subject }.to change { user.tokens.count }.by(-1)
    end
  end

  describe '#update' do
    subject { put :update, params: { login: user.login, id: params_id }, format: :xml, body: xml }

    let(:token) { create(:service_token, executor: user) }
    let(:params_id) { token.id }
    let(:xml) { '<token enabled="false"></token>' }

    render_views

    before do
      login user
    end

    it 'updates the token' do
      expect { subject }.to change { token.reload.enabled }.from(true).to(false)
    end
  end
end
