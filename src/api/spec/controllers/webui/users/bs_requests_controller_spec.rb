RSpec.describe Webui::Users::BsRequestsController do
  describe 'GET #index' do
    context 'when the user has the request_index feature flag disabled' do
      include_context 'a set of bs requests'

      let(:context_params) { {} }
      let(:params) { { user_login: user, format: :json }.merge(context_params) }

      before do
        login user
        get :index, params: params
      end

      it { expect(response).to have_http_status(:success) }
      it { expect(subject).to render_template(:index) }

      it_behaves_like 'a bs requests data table controller'

      context 'with the dataTableId param set to "all_requests_table"' do
        let(:context_params) { { dataTableId: 'all_requests_table' } }

        it 'returns those requests' do
          expect(assigns(:requests_data_table).rows.length).to eq(11)
        end

        it 'assigns the total count of records' do
          expect(assigns(:requests_data_table).records_total).to eq(11)
          expect(assigns(:requests_data_table).count_requests).to eq(11)
        end
      end

      context 'with the dataTableId param set to "requests_in_table"' do
        let(:context_params) { { dataTableId: 'requests_in_table' } }

        it 'returns no requests' do
          expect(assigns(:requests_data_table).rows.length).to eq(0)
        end

        it 'assigns the total count of records' do
          expect(assigns(:requests_data_table).records_total).to eq(0)
          expect(assigns(:requests_data_table).count_requests).to eq(0)
        end
      end
    end

    context 'when the user has the request_index feature flag enabled' do
      let!(:user) { create(:confirmed_user, login: 'king') }
      let(:target_project) { create(:project_with_package, maintainer: user) }
      let(:target_package) { target_project.packages.first }
      let!(:incoming_request) do
        create(:bs_request_with_submit_action,
               description: 'incoming',
               source_package: create(:project),
               target_package: target_package)
      end
      let!(:outgoing_request) do
        create(:bs_request_with_submit_action,
               creator: user,
               description: 'outgoing',
               source_package: target_package,
               target_package: create(:project))
      end
      let!(:request_with_review) do
        create(:delete_bs_request,
               target_project: create(:project),
               staging_project: create(:project),
               review_by_user: user,
               priority: :critical,
               description: 'review_request')
      end

      let(:context_params) { {} }
      let(:params) { { format: :json }.merge(context_params) }

      before do
        login user
        Flipper.enable(:request_index, user)
        get :index, params: params, format: :html
      end

      it { expect(assigns[:bs_requests].map(&:description)).to contain_exactly('incoming', 'outgoing', 'review_request') }

      context 'and the involvement parameter is "incoming"' do
        let(:context_params) { { involvement: ['incoming'] } }

        it { expect(assigns[:bs_requests]).to contain_exactly(incoming_request) }
      end

      context 'and the involvement parameter is "outgoing"' do
        let(:context_params) { { involvement: ['outgoing'] } }

        it { expect(assigns[:bs_requests]).to contain_exactly(outgoing_request) }
      end

      context 'and the involvement parameter is "review"' do
        let(:context_params) { { involvement: ['review'] } }

        it { expect(assigns[:bs_requests]).to contain_exactly(request_with_review) }
      end

      context 'and the involvement parameter is "[incoming, outgoing]"' do
        let(:context_params) { { involvement: %w[incoming outgoing] } }

        it { expect(assigns[:bs_requests].map(&:description)).to contain_exactly('incoming', 'outgoing') }
      end

      context 'and the involvement parameter is "[incoming, review]"' do
        let(:context_params) { { involvement: %w[incoming review] } }

        it { expect(assigns[:bs_requests].map(&:description)).to contain_exactly('incoming', 'review_request') }
      end

      context 'and the involvement parameter is "[outgoing, review]"' do
        let(:context_params) { { involvement: %w[outgoing review] } }

        it { expect(assigns[:bs_requests].map(&:description)).to contain_exactly('outgoing', 'review_request') }
      end

      context 'and the state parameter is used' do
        let(:context_params) { { states: ['review'] } }

        it { expect(assigns[:bs_requests]).to contain_exactly(request_with_review) }
      end

      context 'and the action_type parameter is used' do
        let(:context_params) { { action_types: ['delete'] } }

        it { expect(assigns[:bs_requests]).to contain_exactly(request_with_review) }
      end

      context 'and the creators parameter is used' do
        let(:context_params) { { creators: [user.login] } }

        it { expect(assigns[:bs_requests]).to contain_exactly(outgoing_request) }
      end

      context 'and the priority parameter is used' do
        let(:context_params) { { priorities: ['critical'] } }

        it { expect(assigns[:bs_requests]).to contain_exactly(request_with_review) }
      end

      context 'and the staging_project parameter is used' do
        let(:context_params) { { staging_projects: [request_with_review.staging_project.name] } }

        it { expect(assigns[:bs_requests]).to contain_exactly(request_with_review) }
      end

      context 'and the reviewers parameter is used' do
        let(:context_params) { { reviewers: [user.login] } }

        it { expect(assigns[:bs_requests]).to contain_exactly(request_with_review) }
      end

      context 'and the created_at parameters are used' do
        before do
          request_with_review.update(created_at: DateTime.parse('Mon, 10 Feb 2025 12:00:00'))
        end

        let(:context_params) { { created_at_from: DateTime.parse('Mon, 10 Feb 2025 00:00:00').to_s, created_at_to: DateTime.parse('Mon, 10 Feb 2025 23:59:00').to_s } }

        it { expect(assigns[:bs_requests]).to contain_exactly(request_with_review) }
      end

      context 'and the project_name parameter is used' do
        let(:context_params) { { project_names: [request_with_review.bs_request_actions.first.target_project] } }

        it { expect(assigns[:bs_requests]).to contain_exactly(request_with_review) }
      end

      context 'and the search parameter is used', :thinking_sphinx do
        let(:context_params) { { search: 'review_request' } }

        it { expect(assigns[:bs_requests]).to contain_exactly(request_with_review) }
      end

      context 'and the package_name parameter is used' do
        let(:context_params) { { package_names: [incoming_request.bs_request_actions.first.source_package] } }

        it { expect(assigns[:bs_requests]).to contain_exactly(incoming_request) }
      end
    end
  end
end
