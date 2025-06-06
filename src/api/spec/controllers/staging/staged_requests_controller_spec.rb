RSpec.describe Staging::StagedRequestsController do
  render_views

  let(:other_user) { create(:confirmed_user, login: 'unpermitted_user') }
  let(:user) { create(:confirmed_user, :with_home, login: 'permitted_user') }
  let(:project) { user.home_project }
  let(:staging_workflow) { create(:staging_workflow_with_staging_projects, project: project) }
  let(:group) { staging_workflow.managers_group }
  let(:staging_project) { staging_workflow.staging_projects.first }
  let(:source_project) { create(:project, name: 'source_project') }
  let(:target_package) { create(:package, name: 'target_package', project: project) }
  let(:source_package) { create(:package, name: 'source_package', project: source_project) }
  let(:bs_request) do
    create(:bs_request_with_submit_action,
           state: :review,
           creator: other_user,
           target_package: target_package,
           source_package: source_package,
           description: 'Unstaged Request',
           review_by_group: group)
  end

  describe 'GET #index' do
    subject { get :index, params: { staging_workflow_project: staging_workflow.project.name, staging_project_name: staging_project.name, format: :xml } }

    let!(:staged_request) do
      create(:bs_request_with_submit_action,
             state: :review,
             creator: other_user,
             target_package: target_package,
             source_package: source_package,
             description: 'Staged Request',
             review_by_project: staging_project,
             staging_project: staging_project)
    end

    before do
      login(user)
    end

    it { expect(subject).to have_http_status(:success) }

    it 'returns the staged_requests xml' do
      expect(subject.body).to have_css("staged_requests > request[id='#{staged_request.number}']")
    end
  end

  describe 'POST #create', :vcr do
    subject { post :create, params: params, body: body }

    let(:params) { { staging_workflow_project: staging_workflow.project.name, staging_project_name: staging_project.name, format: :xml } }
    let(:body) { "<requests><request id='#{bs_request.number}'/></requests>" }

    before do
      login user
    end

    it { expect(subject).to have_http_status(:success) }
    it { expect { subject }.to change(staging_project.packages, :count).from(0).to(1) }
    it { expect { subject }.to change(staging_project.staged_requests, :count).from(0).to(1) }

    # FIXME: This is testing Staging::StagedRequests.add_request_not_found_errors, which has it's own spec
    context 'with valid and invalid request number' do
      let(:body) { "<requests><request id='-1'/><request id='#{bs_request.number}'/></requests>" }

      it { expect(response).to have_http_status(:success) }
      it { expect { subject }.to change(staging_project.packages, :count).from(0).to(1) }
      it { expect { subject }.to change(staging_project.staged_requests, :first).from(nil).to(bs_request) }
    end

    # FIXME: This is testing Staging::RequestExcluder.destroy which *should* have it's own spec...
    context 'with excluded requests' do
      let!(:request_exclusion) { create(:request_exclusion, bs_request: bs_request, number: bs_request.number, staging_workflow: staging_workflow) }

      it { expect(subject.headers['X-Opensuse-Errorcode']).to eql('invalid_request') }
      it { expect(subject.body).to match(/Request #{bs_request.number} currently excluded from project home:permitted_user/) }

      context 'with remove_exclusion parameter set' do
        let(:params) do
          {
            staging_workflow_project: staging_workflow.project.name,
            staging_project_name: staging_project.name,
            remove_exclusion: '1',
            format: :xml
          }
        end

        context 'it removes the exclusion and stages the request' do
          it { expect(subject).to have_http_status(:success) }
          it { expect { subject }.to change(staging_workflow.excluded_requests, :count).from(1).to(0) }
          it { expect { subject }.to change(staging_project.staged_requests, :first).from(nil).to(bs_request) }
        end

        context 'it errors if there is no exclusion' do
          let(:params) do
            {
              staging_workflow_project: staging_workflow.project.name,
              staging_project_name: staging_project.name,
              remove_exclusion: '1',
              format: :xml
            }
          end

          before do
            request_exclusion.destroy
          end

          it { expect(subject).to have_http_status(:bad_request) }
          it { expect(subject.headers['X-Opensuse-Errorcode']).to eql('invalid_request') }
          it { expect(subject.body).to match(/Requests with number #{bs_request.number} are not excluded/) }
        end
      end
    end
  end

  describe 'DELETE #destroy', :vcr do
    subject { delete :destroy, params: params, body: body }

    let!(:staged_request) do
      create(:package, project: staging_project, name: target_package.name)
      create(:bs_request_with_submit_action,
             state: :review,
             creator: other_user,
             target_package: target_package,
             source_package: source_package,
             description: 'Staged Request',
             review_by_project: staging_project,
             staging_project: staging_project)
    end
    let(:params) { { staging_workflow_project: staging_workflow.project.name, format: :xml } }
    let(:body) { "<requests><request id='#{staged_request.number}'/></requests>" }

    before do
      login user
    end

    it { expect(response).to have_http_status(:success) }
    it { expect { subject }.to change(staging_project.packages, :count).from(1).to(0) }
    it { expect { subject }.to change(staging_project.staged_requests, :count).from(1).to(0) }
  end

  describe '#set_staging_project' do
    before do
      login user
      post :create, params: { staging_workflow_project: staging_workflow.project.name, staging_project_name: 'does-not-exist', format: :xml },
                    body: "<requests><request id='#{bs_request.number}'/></requests>"
    end

    it { expect(response.headers['X-Opensuse-Errorcode']).to eql('not_found') }
  end

  describe '#check_overall_state' do
    before do
      Delayed::Job.create(handler: "job_class: StagingProjectAcceptJob, project_id: #{staging_project.id}")
      login user
      post :create, params: { staging_workflow_project: staging_workflow.project.name, staging_project_name: staging_project.name, format: :xml },
                    body: "<requests><request id='#{bs_request.number}'/></requests>"
    end

    it { expect(subject.headers['X-Opensuse-Errorcode']).to eql('staging_project_not_in_acceptable_state') }
  end
end
