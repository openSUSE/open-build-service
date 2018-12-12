require 'rails_helper'

RSpec.describe Webui::Projects::MetaController, vcr: true do
  let(:user) { create(:confirmed_user, login: 'tom') }

  describe 'GET #meta' do
    before do
      login user
      get :show, params: { project: user.home_project }
    end

    it { expect(response).to have_http_status(:success) }
  end

  describe 'POST #update' do
    before do
      login user
    end

    context 'with a nonexistent project' do
      let(:post_save_meta) { post :update, params: { project: 'nonexistent_project' }, xhr: true }

      it { expect { post_save_meta }.to raise_error(ActiveRecord::RecordNotFound) }
    end

    context 'with a valid project' do
      context 'without a valid meta' do
        before do
          post :update, params: { project: user.home_project, meta: '<project name="home:tom"><title/></project>' }, xhr: true
        end

        it { expect(flash.now[:error]).not_to be_nil }
        it { expect(response).to have_http_status(:bad_request) }
      end

      context 'with an invalid devel project' do
        before do
          post :update, params: { project: user.home_project,
                                  meta: '<project name="home:tom"><title/><description/><devel project="non-existant"/></project>' }, xhr: true
        end

        it { expect(flash.now[:error]).to eq("Project with name 'non-existant' not found") }
        it { expect(response).to have_http_status(:bad_request) }
      end

      context 'with a valid meta' do
        before do
          post :update, params: { project: user.home_project, meta: '<project name="home:tom"><title/><description/></project>' }, xhr: true
        end

        it { expect(flash.now[:success]).not_to be_nil }
        it { expect(response).to have_http_status(:ok) }
      end

      context 'with a non existing repository path' do
        let(:meta) do
          <<-HEREDOC
          <project name="home:tom">
          <title/>
          <description/>
          <repository name="not-existent">
          <path project="not-existent" repository="standard" />
          </repository>
          </project>
          HEREDOC
        end
        before do
          post :update, params: { project: user.home_project, meta: meta }, xhr: true
        end

        it { expect(flash.now[:error]).to eq('A project with the name not-existent does not exist. Please update the repository path elements.') }
        it { expect(response).to have_http_status(:bad_request) }
      end
    end
  end
end
