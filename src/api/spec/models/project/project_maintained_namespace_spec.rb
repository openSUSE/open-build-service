require 'rails_helper'

RSpec.describe Project do
  describe '.maintained_namespace' do
    let(:maintenance_project) { create(:project, name: 'openSUSE:Maintenance') }
    let(:project) { create(:project) }

    before do
      allow(Project).to receive(:get_maintenance_project).and_return(maintenance_project)
      allow(maintenance_project).to receive(:maintained_project_names).and_return(['franz', 'franz:is', 'franz:is:cool'])
    end

    it 'returns first field by default' do
      allow(project).to receive(:name).and_return('peter:paul')
      expect(project.maintained_namespace).to eq('peter')
    end

    it 'returns maintenance project name sub-projects' do
      allow(project).to receive(:name).and_return('openSUSE:Maintenance:Incidents:1234')
      expect(project.maintained_namespace).to eq('openSUSE:Maintenance')
    end

    it 'returns maintained project name' do
      allow(project).to receive(:name).and_return('franz')
      expect(project.maintained_namespace).to eq('franz')
    end

    it 'returns maintained project name for sub-projects' do
      allow(project).to receive(:name).and_return('franz:is:cool:indeed')
      expect(project.maintained_namespace).to eq('franz:is:cool')
    end
  end
end
