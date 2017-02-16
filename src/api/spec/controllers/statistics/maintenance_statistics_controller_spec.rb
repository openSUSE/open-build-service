require 'rails_helper'
require 'webmock/rspec'

RSpec.describe Statistics::MaintenanceStatisticsController, type: :controller do
  describe 'GET #index' do
    context 'with a project with maintenance statistics' do
      include_context 'a project with maintenance statistics'

      before do
        login(user)

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
