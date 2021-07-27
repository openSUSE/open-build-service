require 'rails_helper'

RSpec.describe Webui::Users::TokensController, type: :controller do
  RSpec.shared_examples 'check for flashing an error' do
    it "doesn't flash a success" do
      expect(subject.request.flash[:success]).to be_nil
    end

    it 'flashes an error' do
      expect(subject.request.flash[:error]).not_to be_nil
    end
  end

  RSpec.shared_examples 'check for flashing a success' do
    it 'flashes a success' do
      expect(subject.request.flash[:success]).not_to be_nil
    end

    it "doesn't flash an error" do
      expect(subject.request.flash[:error]).to be_nil
    end
  end

  let(:user) { create(:confirmed_user, login: 'foo') }
  let(:other_user) { create(:confirmed_user, login: 'bar') }

  before do
    Flipper[:trigger_workflow].enable
    login user
  end

  describe 'GET #index' do
    before do
      create(:service_token, user: user)
      create(:workflow_token, user: user)
      create(:rss_token, user: user)
      create(:release_token, user: other_user)

      get :index
    end

    it { expect(assigns(:tokens).count).to eq(2) }
  end

  describe 'POST #create' do
    let(:project) { create(:project) }
    let(:package) { create(:package, project: project) }

    subject { post :create, xhr: true, params: form_parameters }

    context 'operation is runservice, no project and no package parameters' do
      let(:form_parameters) { { token: { operation: 'runservice' } } }

      include_examples 'check for flashing a success'
    end

    context 'operation is release, with project parameter, without package parameter' do
      let(:form_parameters) { { token: { operation: 'release', project_name: project.name } } }

      include_examples 'check for flashing an error'

      it { expect { subject }.not_to change(Token, :count) }
    end

    context 'operation is rebuild, with project and package parameter' do
      let(:form_parameters) { { token: { operation: 'rebuild', project_name: project.name, package_name: package.name } } }

      include_examples 'check for flashing a success'

      it { expect { subject }.to change(Token, :count).from(0).to(1) }
    end

    context 'operation is workflow' do
      context 'with SCM' do
        let(:form_parameters) { { token: { operation: 'workflow', scm_token: 'test_SCM_token_string' } } }

        include_examples 'check for flashing a success'

        it { expect { subject }.to change(Token, :count).from(0).to(1) }
      end

      context 'without SCM' do
        let(:form_parameters) { { token: { operation: 'workflow' } } }

        include_examples 'check for flashing an error'

        it { expect { subject }.not_to change(Token, :count) }
      end
    end
  end

  describe 'DELETE #destroy' do
    let!(:token) { create(:service_token, user: user) }
    let(:delete_parameters) { { id: token.id } }

    subject { delete :destroy, params: delete_parameters }

    context 'existent token' do
      include_examples 'check for flashing a success'

      it { is_expected.to redirect_to(tokens_path) }
      it { expect { subject }.to change(Token, :count).from(1).to(0) }
    end

    context 'non-existent token' do
      let(:delete_parameters) { { id: token.id + 1 } }

      include_examples 'check for flashing an error'

      it { is_expected.to redirect_to(tokens_path) }
      it { expect { subject }.not_to change(Token, :count) }
    end

    context 'token of other user' do
      let(:token) { create(:service_token, user: other_user) }

      include_examples 'check for flashing an error'

      it { is_expected.to redirect_to(root_path) }
      it { expect { subject }.not_to change(Token, :count) }
    end
  end
end
