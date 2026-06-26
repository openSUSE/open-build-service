RSpec.describe Staging::ExcludedRequestsController do
  render_views

  let(:user) { create(:confirmed_user, :with_home, login: 'user') }
  let(:other_user) { create(:confirmed_user, login: 'other_user') }
  let(:project) { user.home_project }
  let(:staging_workflow) { create(:staging_workflow_with_staging_projects, project: project) }
  let(:group) { staging_workflow.managers_group }
  let(:manager) { create(:confirmed_user, login: 'manager', groups: [group]) }
  let(:source_project) { create(:project, name: 'source_project') }
  let(:target_package) { create(:package, name: 'target_package', project: project) }
  let(:source_package) { create(:package, name: 'source_package', project: source_project) }
  let(:bs_request) do
    create(:bs_request_with_submit_action,
           creator: other_user,
           target_package: target_package,
           source_package: source_package,
           review_by_group: group)
  end

  describe 'GET #index' do
    let!(:request_exclusion1) { create(:request_exclusion, bs_request: bs_request, staging_workflow: staging_workflow, description: 'Request 1') }
    let(:source_package2) { create(:package, name: 'source_package_2', project: source_project) }
    let(:bs_request2) do
      create(:bs_request_with_submit_action,
             creator: other_user,
             target_package: target_package,
             source_package: source_package,
             review_by_group: group)
    end
    let!(:request_exclusion2) { create(:request_exclusion, bs_request: bs_request2, staging_workflow: staging_workflow, description: 'Request 2') }

    before do
      login(user)
      get :index, params: { staging_workflow_project: staging_workflow.project.name, format: :xml }
    end

    it { expect(response).to have_http_status(:success) }

    it 'returns the excluded_requests xml' do
      expect(response.body).to have_css('excluded_requests', count: 1)
      expect(response.body).to have_css('excluded_requests > request', count: 2)
      expect(response.body).to have_css("excluded_requests > request[id='#{bs_request.number}']")
      expect(response.body).to have_css("excluded_requests > request[id='#{bs_request2.number}']")
      expect(response.body).to have_css("excluded_requests > request[package='#{bs_request.first_target_package}']")
      expect(response.body).to have_css("excluded_requests > request[package='#{bs_request2.first_target_package}']")
      expect(response.body).to have_css("excluded_requests > request[description='Request 1']")
      expect(response.body).to have_css("excluded_requests > request[description='Request 2']")
    end
  end

  describe 'POST #create' do
    before { login(manager) }

    context 'succeeds' do
      subject { staging_workflow.request_exclusions.last }

      before do
        post :create, params: { staging_workflow_project: staging_workflow.project.name, format: :xml },
                      body: "<excluded_requests><request id='#{bs_request.number}' description='hey'/></excluded_requests>"
      end

      it { expect(response).to have_http_status(:success) }
      it { expect(subject.bs_request).to eq(bs_request) }
      it { expect(subject.description).to eq('hey') }
    end

    context 'fails: project does not exist' do
      before do
        post :create, params: { staging_workflow_project: 'i_do_not_exist', format: :xml },
                      body: "<excluded_requests><request id='#{bs_request.number}' description='hey'/></excluded_requests>"
      end

      it { expect(response).to have_http_status(:not_found) }
    end

    context 'fails: project without staging_workflow' do
      let(:project_without_staging) { create(:project, name: 'no_staging') }

      before do
        post :create, params: { staging_workflow_project: project_without_staging, format: :xml },
                      body: "<excluded_requests><request id='#{bs_request.number}' description='hey'/></excluded_requests>"
      end

      it { expect(response).to have_http_status(:not_found) }
    end

    context 'fails: no description, invalid request exclusion' do
      before do
        post :create, params: { staging_workflow_project: staging_workflow.project.name, format: :xml },
                      body: "<excluded_requests><request id='#{bs_request.number}'/></excluded_requests>"
      end

      it { expect(response).to have_http_status(:bad_request) }
    end

    context 'fails: non-existent bs_request number, invalid request exclusion' do
      before do
        post :create, params: { staging_workflow_project: staging_workflow.project.name, format: :xml },
                      body: "<excluded_requests><request id='43_543'/></excluded_requests>"
      end

      it { expect(response).to have_http_status(:bad_request) }
    end

    context 'fails: request belongs to a staging project, invalid request exclusion' do
      before do
        bs_request.staging_project = staging_workflow.staging_projects.first
        bs_request.save
        post :create, params: { staging_workflow_project: staging_workflow.project.name, format: :xml },
                      body: "<excluded_requests><request id='43_543'/></excluded_requests>"
      end

      it { expect(response).to have_http_status(:bad_request) }
    end
  end

  describe 'DELETE #destroy' do
    before { login(manager) }

    let(:request_exclusion) { create(:request_exclusion, bs_request: bs_request, number: bs_request.number, staging_workflow: staging_workflow) }

    context 'succeeds' do
      subject do
        delete :destroy, params: { staging_workflow_project: staging_workflow.project.name, format: :xml },
                         body: "<requests><request id='#{bs_request.number}'/></requests>"
      end

      before { request_exclusion }

      it { expect { subject }.to(change { staging_workflow.request_exclusions.count }.by(-1)) }

      context 'response' do
        before { subject }

        it { expect(response).to have_http_status(:success) }
      end
    end

    context 'fails: request not excluded' do
      before do
        delete :destroy, params: { staging_workflow_project: staging_workflow.project.name, format: :xml },
                         body: "<requests><request id='#{bs_request.number}'/></requests>"
      end

      it { expect(response).to have_http_status(:bad_request) }
    end

    context 'fails: unable to destroy' do
      before do
        request_exclusion
        allow_any_instance_of(ActiveRecord::Relation).to receive(:destroy_all).and_return([])
        delete :destroy, params: { staging_workflow_project: staging_workflow.project.name, format: :xml },
                         body: "<requests><request id='#{bs_request.number}'/></requests>"
      end

      it { expect(response).to have_http_status(:bad_request) }
    end
  end
end
