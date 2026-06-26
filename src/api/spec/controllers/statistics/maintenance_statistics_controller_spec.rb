require 'webmock/rspec'

RSpec.describe Statistics::MaintenanceStatisticsController do
  render_views

  describe 'GET #index' do
    context 'with a project with maintenance statistics' do
      include_context 'a project with maintenance statistics'

      context 'and no access restrictions' do
        before do
          get :index, params: { format: :xml, project: project.name }
        end

        it { expect(response).to have_http_status(:success) }

        it 'assigns the project to an instance variable' do
          expect(assigns[:project]).to be_a(Project)
        end

        it 'assigns the maintenance_statistics array to an instance variable' do
          expect(assigns[:maintenance_statistics]).to be_an(Array)
        end

        it { expect(response.body).to include("<maintenanceincident project=\"#{project.name}\">") }
        it { expect(response.body).to include("<entry type=\"project_created\" when=\"#{project.created_at}\"/>") }
      end

      context 'but access got disabled' do
        before do
          project.flags.create(attributes_for(:access_flag, status: 'disable'))
          # Strange enough the access check only works for projects that have a
          # relationship that points to a user
          project.relationships.create(attributes_for(:relationship_project_user, user_id: create(:user).id))

          login(create(:user))
          get :index, params: { format: :xml, project: project.name }
        end

        it 'hides the project' do
          expect(response).to have_http_status(:not_found)
        end
      end

      context 'with a remote project' do
        let(:remote) { create(:remote_project, remoteurl: 'http://remoteproject.com') }

        before do
          stub_request(:get, maintenance_statistics_url(host: remote.remoteurl, project: 'my_project'))
            .to_return(status: 200, body: '<received><xml/></received>')

          get :index, params: { format: :xml, project: "#{remote}:my_project" }
        end

        it 'forwards the request to the remote instance' do
          expect(a_request(:get, maintenance_statistics_url(host: remote.remoteurl, project: 'my_project'))).to have_been_made.once
        end

        it 'responds with the xml received from the remote instance' do
          expect(response).to have_http_status(:success)
          expect(Xmlhash.parse(response.body)).to eq('xml' => {})
        end
      end
    end

    context 'with no project existing' do
      let(:user) { create(:confirmed_user) }

      before do
        login(user)

        get :index, params: { format: :xml, project: 'NonExistentProject' }
      end

      it { expect(response).to have_http_status(:not_found) }
    end
  end
end
