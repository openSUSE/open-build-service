require 'rails_helper'

RSpec.describe Webui::Users::TokensController do
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
    login user
  end

  describe 'GET #index' do
    before do
      create(:service_token, executor: user)
      create(:workflow_token, executor: user)
      create(:rss_token, executor: user)
      create(:release_token, executor: other_user)

      get :index
    end

    it { expect(assigns(:tokens).count).to eq(2) }
  end

  describe 'POST #create' do
    let(:project) { create(:project) }
    let(:package) { create(:package, project: project) }

    subject { post :create, xhr: true, params: form_parameters }

    context 'type is runservice' do
      let(:form_parameters) { { token: { type: 'runservice' } } }

      include_examples 'check for flashing a success'
    end

    context 'type is runservice, with name' do
      let(:form_parameters) { { token: { type: 'runservice', description: 'My first token' } } }

      include_examples 'check for flashing a success'
      it { is_expected.to redirect_to(token_path(Token.last)) }
    end

    context 'type is release, with project parameter, without package parameter' do
      let(:form_parameters) { { token: { type: 'release' }, project_name: project.name } }

      include_examples 'check for flashing an error'

      it { expect { subject }.not_to change(Token, :count) }
    end

    context 'type is rebuild, with project and package parameter' do
      let(:form_parameters) { { token: { type: 'rebuild' }, project_name: project.name, package_name: package.name } }

      include_examples 'check for flashing a success'

      it { expect { subject }.to change(Token, :count).from(0).to(1) }
      it { is_expected.to redirect_to(token_path(Token.last)) }
    end

    context 'type is rebuild but project does not exist' do
      let(:form_parameters) { { token: { type: 'rebuild' }, description: 'token description', project_name: 'non-existing project' } }

      include_examples 'check for flashing an error'

      it { expect { subject }.not_to change(Token, :count) }
      it { is_expected.to render_template(:new) }
    end

    context 'type is workflow' do
      context 'with SCM' do
        let(:form_parameters) { { token: { type: 'workflow', scm_token: 'test_SCM_token_string' } } }

        include_examples 'check for flashing a success'

        it { expect { subject }.to change(Token, :count).from(0).to(1) }
        it { is_expected.to redirect_to(token_path(Token.last)) }
      end

      context 'without SCM' do
        let(:form_parameters) { { token: { type: 'workflow' } } }

        include_examples 'check for flashing an error'

        it { expect { subject }.not_to change(Token, :count) }
      end
    end
  end

  describe 'PUT #update' do
    subject { put :update, params: update_parameters }

    context 'updates a workflow token belonging to the logged-in user' do
      let(:token) { create(:workflow_token, executor: user, scm_token: 'something') }
      let(:update_parameters) { { id: token.id, token: { description: 'My first token', scm_token: 'something_else' } } }

      include_examples 'check for flashing a success'

      it { is_expected.to redirect_to(tokens_path) }
      it { expect { subject }.to change { token.reload.scm_token }.from('something').to('something_else') }
      it { expect { subject }.to change { token.reload.description }.from('').to('My first token') }
    end

    context 'updates the token string of a token belonging to the logged-in user' do
      let(:token) { create(:service_token, executor: user) }
      let(:update_parameters) { { id: token.id } }

      subject { put :update, params: update_parameters, xhr: true }

      include_examples 'check for flashing a success'

      it { expect { subject }.to(change { token.reload.string }) }
      it { expect { subject }.not_to(change { token.reload.scm_token }) }
    end

    context 'redirects to index when passing a non-existent token' do
      let(:update_parameters) { { id: -1 } }

      include_examples 'check for flashing an error'

      it { is_expected.to redirect_to(tokens_path) }
    end

    context 'does not update a token belonging to another user' do
      let(:token) { create(:service_token, executor: other_user) }
      let(:update_parameters) { { id: token.id, token: { scm_token: 'something' } } }

      include_examples 'check for flashing an error'

      it { is_expected.to redirect_to(root_path) }
      it { expect { subject }.not_to change(token, :scm_token) }
    end
  end

  describe 'DELETE #destroy' do
    let!(:token) { create(:service_token, executor: user) }
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
      let(:token) { create(:service_token, executor: other_user) }

      include_examples 'check for flashing an error'

      it { is_expected.to redirect_to(root_path) }
      it { expect { subject }.not_to change(Token, :count) }
    end
  end
end
