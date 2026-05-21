RSpec.describe Webui::SessionController do
  let(:user) { create(:confirmed_user, login: 'tom') }

  before do
    subject
  end

  describe 'POST #create' do
    subject { post :create, params: { username: user.login, password: 'buildservice' } }

    it { expect(session[:login]).to eq(user.login) }
    it { expect(response).to redirect_to user_url(user) }

    context 'wrong password' do
      subject { post :create, params: { username: user.login, password: 'password123' } }

      it { expect(session[:login]).to be_nil }
      it { expect(flash[:error]).to eq('Authentication Failed') }
    end

    context 'wrong user' do
      subject { post :create, params: { username: 'hans', password: 'buildservice' } }

      it { expect(session[:login]).to be_nil }
      it { expect(flash[:error]).to eq('Authentication Failed') }
    end
  end
end
