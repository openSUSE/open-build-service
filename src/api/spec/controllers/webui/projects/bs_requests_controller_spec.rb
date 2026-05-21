RSpec.describe Webui::Projects::BsRequestsController do
  describe 'GET #index' do
    context 'when the user has the request_index feature flag disabled' do
      include_context 'a set of bs requests'

      let(:base_params) { { project: source_project, format: :json } }
      let(:context_params) { {} }
      let(:params) { base_params.merge(context_params) }

      before do
        get :index, params: params
      end

      it { expect(response).to have_http_status(:success) }
      it { expect(subject).to render_template(:index) }

      it_behaves_like 'a bs requests data table controller'
      it_behaves_like 'a bs requests data table controller with state and type options'
    end

    context 'when the user has the request_index feature flag enabled' do
      let!(:user) { create(:confirmed_user, login: 'king') }
      let(:params) { base_params.merge(context_params) }

      context 'when looking at the target_projects requests' do
        let(:target_project) { create(:project_with_package) }
        let(:target_package) { target_project.packages.first }
        let!(:incoming_request) do
          create(:bs_request_with_submit_action,
                 creator: user,
                 priority: 'critical',
                 source_package: create(:project),
                 target_package: target_package)
        end
        let!(:outgoing_request) do
          create(:bs_request_with_submit_action,
                 creator: user,
                 priority: 'critical',
                 source_package: target_package,
                 target_package: create(:project))
        end
        let!(:request_with_review) do
          create(:bs_request_with_submit_action,
                 review_by_project: target_project,
                 creator: user,
                 priority: 'critical')
        end
        let(:context_params) { {} }
        let(:base_params) { { project: target_project, format: :json } }

        before do
          login user
          Flipper.enable(:request_index, user)
          get :index, params: params, format: :html
        end

        it { expect(assigns[:bs_requests]).to contain_exactly(incoming_request, outgoing_request, request_with_review) }

        context 'and the involvement parameters is "incoming"' do
          let(:context_params) { { involvement: ['incoming'] } }

          it { expect(assigns[:bs_requests]).to contain_exactly(incoming_request) }
        end

        context 'and the involvement parameters is "outgoing"' do
          let(:context_params) { { involvement: ['outgoing'] } }

          it { expect(assigns[:bs_requests]).to contain_exactly(outgoing_request) }
        end

        context 'and the involvement parameters is "review"' do
          let(:context_params) { { involvement: ['review'] } }

          it { expect(assigns[:bs_requests]).to contain_exactly(request_with_review) }
        end
      end

      context 'when looking at the source_projects requests' do
        let(:source_project) { create(:project_with_package) }
        let(:source_package) { source_project.packages.first }
        let!(:incoming_request) do
          create(:bs_request_with_submit_action,
                 creator: user,
                 priority: 'critical',
                 source_package: create(:project),
                 target_package: source_package)
        end
        let!(:outgoing_request) do
          create(:bs_request_with_submit_action,
                 creator: user,
                 priority: 'critical',
                 source_package: source_package,
                 target_package: create(:project))
        end
        let!(:request_with_review) do
          create(:bs_request_with_submit_action,
                 review_by_project: source_project,
                 creator: user,
                 priority: 'critical')
        end
        let(:base_params) { { project: source_project, format: :json } }

        before do
          login user
          Flipper.enable(:request_index, user)
          get :index, params: params, format: :html
        end

        context 'and the involvement parameters is "incoming"' do
          let(:context_params) { { involvement: ['incoming'] } }

          it { expect(assigns[:bs_requests]).to contain_exactly(incoming_request) }
        end

        context 'and the involvement parameters is "outgoing"' do
          let(:context_params) { { involvement: ['outgoing'] } }

          it { expect(assigns[:bs_requests]).to contain_exactly(outgoing_request) }
        end

        context 'and the involvement parameters is "review"' do
          let(:context_params) { { involvement: ['review'] } }

          it { expect(assigns[:bs_requests]).to contain_exactly(request_with_review) }
        end
      end
    end
  end
end
