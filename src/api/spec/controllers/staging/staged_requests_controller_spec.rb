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
           description: 'BsRequest 1',
           number: 1,
           review_by_group: group)
  end
  let(:delete_request) { create(:delete_bs_request, target_package: target_package) }

  describe 'GET #index' do
    before do
      login(user)
      bs_request.staging_project = staging_project
      bs_request.save
      get :index, params: { staging_workflow_project: staging_workflow.project.name, staging_project_name: staging_project.name, format: :xml }
    end

    it { expect(response).to have_http_status(:success) }

    it 'returns the staged_requests xml' do
      expect(response.body).to have_css('staged_requests > request', count: 1)
    end
  end

  describe 'POST #create' do
    context 'invalid user' do
      before do
        staging_workflow

        login other_user
        post :create, params: { staging_workflow_project: staging_workflow.project.name, staging_project_name: staging_project.name, format: :xml },
                      body: "<requests><request id='#{bs_request.number}'/></requests>"
      end

      it { expect(response).to have_http_status(:forbidden) }
    end

    context 'non-existent staging project' do
      before do
        login user
        post :create, params: { staging_workflow_project: staging_workflow.project.name, staging_project_name: 'does-not-exist', format: :xml },
                      body: "<requests><request id='#{bs_request.number}'/></requests>"
      end

      it { expect(response).to have_http_status(:not_found) }
    end

    context 'with valid and invalid request number', :vcr do
      before do
        login user
        post :create, params: { staging_workflow_project: staging_workflow.project.name, staging_project_name: staging_project.name, format: :xml },
                      body: "<requests><request id='-1'/><request id='#{bs_request.number}'/></requests>"
      end

      it { expect(response).to have_http_status(:bad_request) }
      it { expect(staging_project.packages.pluck(:name)).to contain_exactly(target_package.name) }
    end

    context 'with valid staging_project but staging project is being merged' do
      before do
        Delayed::Job.create(handler: "job_class: StagingProjectAcceptJob, project_id: #{staging_project.id}")
        login user
        post :create, params: { staging_workflow_project: staging_workflow.project.name, staging_project_name: staging_project.name, format: :xml },
                      body: "<requests><request id='#{bs_request.number}'/></requests>"
      end

      it { expect(response).to have_http_status(:failed_dependency) }

      it 'responds with an error' do
        expect(response.body).to have_css('status[code=staging_project_not_in_acceptable_state]')
      end
    end

    context 'with valid staging_project', :vcr do
      before do
        login user
        post :create, params: { staging_workflow_project: staging_workflow.project.name, staging_project_name: staging_project.name, format: :xml },
                      body: "<requests><request id='#{bs_request.number}'/></requests>"
      end

      it { expect(response).to have_http_status(:success) }
      it { expect(staging_project.packages.pluck(:name)).to contain_exactly(target_package.name) }
      it { expect(staging_project.staged_requests).to include(bs_request) }
      it { expect(response.body).to have_css('status[code=ok]') }
    end

    context 'with delete request', :vcr do
      before do
        login user
        post :create, params: { staging_workflow_project: staging_workflow.project.name, staging_project_name: staging_project.name, format: :xml },
                      body: "<requests><request id='#{delete_request.number}'/></requests>"
      end

      it { expect(response).to have_http_status(:success) }
      it { expect(staging_project.packages.pluck(:name)).not_to include(target_package.name) }
      it { expect(staging_project.staged_requests).to include(delete_request) }
      it { expect(response.body).to have_css('status[code=ok]') }
    end

    context 'with an excluded request', :vcr do
      subject do
        login user
        post :create, params: params, body: body
      end

      context 'when not providing the remove exclusion parameter' do
        let(:params) do
          {
            staging_workflow_project: staging_workflow.project.name,
            staging_project_name: staging_project.name,
            format: :xml
          }
        end
        let(:body) { "<requests><request id='#{bs_request.number}'/></requests>" }

        before do
          create(:request_exclusion,
                 bs_request: bs_request,
                 number: bs_request.number,
                 staging_workflow: staging_workflow)
          subject
        end

        it { expect(response).to have_http_status(:bad_request) }
        it { expect(response.body).to match(/invalid_request/) }
        it { expect(response.body).to match(/Request #{bs_request.number} currently excluded from project #{staging_workflow.project.name}. Use --remove-exclusion if you want to force this action./) }
      end

      context 'when providing the remove exclusion parameter' do
        let(:params) do
          {
            staging_workflow_project: staging_workflow.project.name,
            staging_project_name: staging_project.name,
            remove_exclusion: '1',
            format: :xml
          }
        end
        let(:body) { "<requests><request id='#{bs_request.number}'/></requests>" }

        before do
          create(:request_exclusion,
                 bs_request: bs_request,
                 number: bs_request.number,
                 staging_workflow: staging_workflow)
          subject
        end

        it { expect(response).to have_http_status(:success) }
        it { expect(staging_project.packages.pluck(:name)).to contain_exactly(target_package.name) }
        it { expect(staging_project.staged_requests).to include(bs_request) }
        it { expect(response.body).to have_css('status[code=ok]') }
      end
    end

    context 'when providing the remove exclusion parameter', :vcr do
      subject do
        login user
        post :create, params: params, body: body
      end

      context 'and not having any excluded request' do
        let(:params) do
          {
            staging_workflow_project: staging_workflow.project.name,
            staging_project_name: staging_project.name,
            remove_exclusion: '1',
            format: :xml
          }
        end
        let(:body) { "<requests><request id='#{bs_request.number}'/></requests>" }

        before { subject }

        it { expect(response).to have_http_status(:bad_request) }
        it { expect(response.body).to match(/invalid_request/) }
        it { expect(response.body).to match(/Requests with number #{bs_request.number} are not excluded/) }
      end
    end

    context 'when providing two request', :vcr do
      subject do
        login user
        post :create, params: params, body: body
      end

      context 'and none is excluded' do
        let(:params) do
          {
            staging_workflow_project: staging_workflow.project.name,
            staging_project_name: staging_project.name,
            format: :xml
          }
        end
        let(:body) { "<requests><request id='#{bs_request.number}'/><request id='#{another_bs_request.number}'/></requests>" }

        before { subject }

        context 'with the same package' do
          let(:another_bs_request) do
            create(:bs_request_with_submit_action,
                   state: :review,
                   creator: other_user,
                   target_package: target_package,
                   source_package: source_package,
                   description: 'BsRequest 2',
                   number: 2,
                   review_by_group: group)
          end

          it { expect(response).to have_http_status(:bad_request) }
          it { expect(response.body).to match(/Can't stage request '#{another_bs_request.number}'/) }
          it { expect(staging_project.staged_requests).to include(bs_request) }
          it { expect(staging_project.staged_requests).not_to include(another_bs_request) }
        end

        context 'with another package' do
          let(:another_target_package) { create(:package, name: 'another_target_package', project: project) }
          let(:another_bs_request) do
            create(:bs_request_with_submit_action,
                   state: :review,
                   creator: other_user,
                   target_package: another_target_package,
                   source_package: source_package,
                   description: 'BsRequest 2',
                   number: 2,
                   review_by_group: group)
          end

          it { expect(response).to have_http_status(:success) }
          it { expect(staging_project.staged_requests).to include(bs_request) }
          it { expect(staging_project.staged_requests).to include(another_bs_request) }
          it { expect(response.body).to have_css('status[code=ok]') }
        end
      end

      context 'and one is excluded but the other is not' do
        let(:request_to_exclude) do
          create(:bs_request_with_submit_action,
                 state: :review,
                 creator: other_user,
                 target_package: target_package,
                 source_package: source_package,
                 description: 'Request with exclusion',
                 number: 2,
                 review_by_group: group)
        end

        context 'when not providing the remove exclusion parameter' do
          let(:params) do
            {
              staging_workflow_project: staging_workflow.project.name,
              staging_project_name: staging_project.name,
              format: :xml
            }
          end
          let(:body) { "<requests><request id='#{bs_request.number}'/><request id='#{request_to_exclude.number}'/></requests>" }

          before do
            create(:request_exclusion,
                   bs_request: request_to_exclude,
                   number: request_to_exclude.number,
                   staging_workflow: staging_workflow)
            subject
          end

          it { expect(response).to have_http_status(:bad_request) }

          it 'did not stage all the requests' do
            expect(staging_project.staged_requests).to include(bs_request)
          end

          it 'still has an exclusion left' do
            expect(staging_workflow.excluded_requests).to include(request_to_exclude)
          end

          it 'returns an error saying which request was not staged' do
            expect(response.body)
              .to match(/Request #{request_to_exclude.number} currently excluded from project #{staging_workflow.project.name}. Use --remove-exclusion if you want to force this action./)
          end
        end

        context 'when providing the remove exclusion parameter' do
          let(:params) do
            {
              staging_workflow_project: staging_workflow.project.name,
              staging_project_name: staging_project.name,
              remove_exclusion: true,
              format: :xml
            }
          end
          let(:body) { "<requests><request id='#{bs_request.number}'/><request id='#{request_to_exclude.number}'/></requests>" }

          before do
            create(:request_exclusion,
                   bs_request: request_to_exclude,
                   number: request_to_exclude.number,
                   staging_workflow: staging_workflow)
            subject
          end

          it { expect(response).to have_http_status(:bad_request) }

          it 'did stage all the requests' do
            expect(staging_project.staged_requests).to be_empty
          end

          it 'still has an exclusion left' do
            expect(staging_workflow.excluded_requests).to include(request_to_exclude)
          end

          it 'returns an error saying which request is not excluded' do
            expect(response.body)
              .to match(/Requests with number #{bs_request.number} are not excluded/)
          end
        end
      end
    end

    context 'with non-existent target package', :vcr do
      let(:bs_request) do
        create(:bs_request_with_submit_action,
               state: :review,
               creator: other_user,
               target_project: project,
               target_package: 'new_package',
               source_package: source_package,
               description: 'BsRequest 1',
               number: 1,
               review_by_group: group)
      end

      before do
        login user
        post :create, params: { staging_workflow_project: staging_workflow.project.name, staging_project_name: staging_project.name, format: :xml },
                      body: "<requests><request id='#{bs_request.number}'/></requests>"
      end

      it { expect(response).to have_http_status(:success) }
      it { expect(staging_project.packages.pluck(:name)).to contain_exactly('new_package') }
      it { expect(staging_project.staged_requests).to include(bs_request) }
      it { expect(response.body).to have_css('status[code=ok]') }
    end
  end

  describe 'DELETE #destroy', :vcr do
    let!(:package) { create(:package, name: target_package, project: staging_project) }
    let!(:review_by_project) { create(:review, by_project: staging_project, bs_request: bs_request) }

    before do
      login(group.users.first)
      bs_request.staging_project = staging_project
      bs_request.save
      bs_request.change_review_state(:accepted, by_group: group.title, comment: 'accepted')
      logout
    end

    context 'invalid user' do
      before do
        login other_user
        delete :destroy, params: { staging_workflow_project: staging_workflow.project.name, format: :xml },
                         body: "<requests><request id='#{bs_request.number}'/></requests>"
      end

      it { expect(response).to have_http_status(:forbidden) }
    end

    context 'valid staging project and valid user' do
      context 'with valid request number' do
        before do
          login user
          delete :destroy, params: { staging_workflow_project: staging_workflow.project.name, format: :xml },
                           body: "<requests><request id='#{bs_request.number}'/></requests>"
        end

        it { expect(response).to have_http_status(:success) }
        it { expect(staging_project.packages).to be_empty }
        it { expect(staging_project.staged_requests).to be_empty }
      end

      context 'with valid and invalid request number' do
        before do
          login user
          delete :destroy, params: { staging_workflow_project: staging_workflow.project.name, format: :xml },
                           body: "<requests><request id='-1'/><request id='#{bs_request.number}'/></requests>"
        end

        it { expect(response).to have_http_status(:bad_request) }
        it { expect(staging_project.packages).to be_empty }
        it { expect(staging_project.staged_requests).to be_empty }
      end

      context 'with revoked request' do
        before do
          login user
          bs_request.state = :revoked
          bs_request.save
          delete :destroy, params: { staging_workflow_project: staging_workflow.project.name, staging_project_name: staging_project.name, format: :xml },
                           body: "<requests><request id='#{bs_request.number}'/></requests>"
        end

        it { expect(response).to have_http_status(:success) }
        it { expect(staging_project.packages).to be_empty }
        it { expect(staging_project.staged_requests).to be_empty }
      end

      context 'with declined request' do
        before do
          login user
          bs_request.change_state(newstate: 'declined', user: user.login, comment: 'Fake comment')
        end

        context 'when is unstaged by the same user' do
          before do
            delete :destroy, params: { staging_workflow_project: staging_workflow.project.name, format: :xml },
                             body: "<requests><request id='#{bs_request.number}'/></requests>"
          end

          it { expect(response).to have_http_status(:success) }
          it { expect(staging_project.packages).to be_empty }
          it { expect(staging_project.staged_requests).to be_empty }
          it { expect(bs_request.reviews.where(by_group: group.title, state: 'new')).to be_present }
          it { expect(bs_request.reviews.where(by_project: staging_project.name, state: 'new')).to be_empty }

          context 'when the declined request was unstaged and reopened' do
            before do
              login user
              bs_request.change_state(newstate: 'new', user: user.login, comment: 'Fake comment')
            end

            it { expect(bs_request.state).to eq(:review) }
            it { expect(staging_project.staged_requests).to be_empty }
            it { expect(staging_workflow.unassigned_requests).to include(bs_request) }
          end
        end

        context 'when is unstaged by other manager' do
          let(:manager) { create(:confirmed_user, login: 'manager', groups: [group]) }
          let!(:relationship_project_user) { create(:relationship_project_user, project: project, user: manager) }

          before do
            login manager
            delete :destroy, params: { staging_workflow_project: staging_workflow.project.name, format: :xml },
                             body: "<requests><request id='#{bs_request.number}'/></requests>"
          end

          it { expect(response).to have_http_status(:success) }
          it { expect(staging_project.packages).to be_empty }
          it { expect(staging_project.staged_requests).to be_empty }
          it { expect(bs_request.reviews.where(by_group: group.title, state: 'new')).to be_present }
          it { expect(bs_request.reviews.where(by_project: staging_project.name, state: 'new')).to be_empty }

          context 'when the declined request was unstaged and reopened' do
            let(:other_manager) { create(:confirmed_user, login: 'other_manager', groups: [group]) }

            before do
              login other_manager
              bs_request.change_state(newstate: 'new', user: other_manager.login, comment: 'Fake comment')
            end

            it { expect(bs_request.state).to eq(:review) }
            it { expect(staging_project.staged_requests).to be_empty }
            it { expect(staging_workflow.unassigned_requests).to include(bs_request) }
          end
        end
      end
    end

    context 'with valid staging_project but staging project is being merged' do
      before do
        Delayed::Job.create(handler: "job_class: StagingProjectAcceptJob, project_id: #{staging_project.id}")
        login user
        delete :destroy, params: { staging_workflow_project: staging_workflow.project.name, format: :xml },
                         body: "<requests><request id='#{bs_request.number}'/></requests>"
      end

      it { expect(response).to have_http_status(:bad_request) }
      it { expect(staging_project.packages).not_to be_empty }
      it { expect(staging_project.staged_requests).not_to be_empty }
    end
  end
end
