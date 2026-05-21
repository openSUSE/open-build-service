require 'ostruct' # for OpenStruct

RSpec.describe Webui::Projects::MetaController, :vcr do
  let(:user) { create(:confirmed_user, :with_home, login: 'tom') }

  describe 'GET #meta' do
    before do
      login user
      get :show, params: { project_name: user.home_project }
    end

    it { expect(response).to have_http_status(:success) }
  end

  describe 'POST #update' do
    before do
      login user
    end

    context 'with a valid project' do
      context 'without a valid meta' do
        before do
          allow(MetaControllerService::ProjectUpdater).to receive(:new) {
            -> { OpenStruct.new(valid?: false, errors: 'yada') }
          }

          post :update, params: { project_name: user.home_project, meta: '<project name="home:tom"><title/></project>' }, xhr: true
        end

        it { expect(flash.now[:error]).not_to be_nil }
        it { expect(response).to have_http_status(:bad_request) }
      end

      context 'with a valid meta' do
        before do
          allow(MetaControllerService::ProjectUpdater).to receive(:new) {
            -> { OpenStruct.new(valid?: true, errors: '') }
          }
          post :update, params: { project_name: user.home_project, meta: '<project name="home:tom"><title/><description/></project>' }, xhr: true
        end

        it { expect(flash.now[:success]).not_to be_nil }
        it { expect(response).to have_http_status(:ok) }
      end
    end
  end
end
