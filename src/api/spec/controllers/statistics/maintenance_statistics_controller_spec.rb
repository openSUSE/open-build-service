require 'rails_helper'
require 'webmock/rspec'

RSpec.describe Statistics::MaintenanceStatisticsController, type: :controller do
  describe 'GET #index' do
    context 'with a project with maintenance statistics' do
      include_context 'a project with maintenance statistics'

      context 'and no access restrictions' do
        before do
          get :index, params: { format: :xml, project: project.name }
        end

        it { is_expected.to respond_with(:success) }

        it 'assigns the project to an instance variable' do
          expect(assigns[:project]).to be_a(Project)
        end

        it 'assigns the maintenance_statistics array to an instance variable' do
          expect(assigns[:maintenance_statistics]).to be_an(Array)
        end
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
          assert_response :not_found
        end
      end
    end

    context 'with no project existing' do
      let(:user) { create(:confirmed_user) }

      before do
        login(user)

        get :index, params: { format: :xml, project: 'NonExistantProject' }
      end

      it { is_expected.to respond_with(:not_found) }
    end
  end
end
