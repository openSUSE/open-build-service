require 'rails_helper'
require 'ostruct'

RSpec.describe StagingProjectLinkComponent, type: :component do
  context 'when the staging project has a title' do
    let(:staging_workflow) { build_stubbed(:staging_workflow) }
    let(:staging_project) { build_stubbed(:project, name: 'Staging:A', title: 'My Project Custom Title') }

    before do
      render_inline(described_class.new(staging_project: staging_project, staging_workflow: staging_workflow))
    end

    it do
      expect(rendered_content).to have_link('My Project Custom Title')
    end
  end

  context "when the staging project doesn't have a title" do
    context 'but is a subproject of the staging workflow project' do
      let(:staging_workflow_project) { build_stubbed(:project, name: 'SUSE') }
      let(:staging_workflow) { build_stubbed(:staging_workflow, project: staging_workflow_project) }
      let(:staging_project) { build_stubbed(:project, name: 'SUSE:Staging:A', title: nil, staging_workflow: staging_workflow) }

      before do
        render_inline(described_class.new(staging_project: staging_project, staging_workflow: staging_workflow))
      end

      it do
        expect(rendered_content).to have_link('Staging:A')
      end
    end

    context 'but is not a subproject of the staging workflow project' do
      let(:staging_workflow_project) { build_stubbed(:project, name: 'SUSE') }
      let(:staging_workflow) { build_stubbed(:staging_workflow, project: staging_workflow_project) }
      let(:staging_project) { build_stubbed(:project, name: 'home:user123', title: nil, staging_workflow: staging_workflow) }

      before do
        render_inline(described_class.new(staging_project: staging_project, staging_workflow: staging_workflow))
      end

      it do
        expect(rendered_content).to have_link('home:user123')
      end
    end
  end
end
