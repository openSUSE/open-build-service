require 'rails_helper'

RSpec.describe Staging::ProjectDecorator do
  let(:workflow_project) { create(:project, name: 'SUSE') }
  let(:staging_workflow) { create(:staging_workflow_with_staging_projects, project: workflow_project) }
  let(:staging_project) { staging_workflow.staging_projects.first }

  subject do
    Staging::ProjectDecorator.new(staging_project)
  end

  context 'when the project has a title' do
    before do
      staging_project.update(title: 'A')
    end

    it 'returns the title' do
      expect(subject.title).to eql('A')
    end
  end

  context 'when the project does not have a title' do
    context 'and the project is a subproject of the workflow project' do
      it 'returns the project name without the workflow part' do
        expect(subject.title).to eql('Staging:A')
      end
    end

    context 'and the project is not a subproject of the workflow project' do
      let(:staging_project) { create(:project, title: '', name: 'OpenSUSE') }

      before do
        staging_workflow.staging_projects << staging_project
      end

      it 'returns the project name' do
        expect(subject.title).to eql('OpenSUSE')
      end
    end
  end
end
