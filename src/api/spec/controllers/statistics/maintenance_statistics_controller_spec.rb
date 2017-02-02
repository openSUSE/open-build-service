require 'rails_helper'
require 'webmock/rspec'

RSpec.describe Statistics::MaintenanceStatisticsController, type: :controller do
  describe 'GET #index' do
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
end
