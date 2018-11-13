require 'rails_helper'

RSpec.describe Staging::Workflow, type: :model do
  let(:project) { create(:project_with_package) }
  let(:staging_workflow) { create(:staging_workflow_with_staging_projects, project: project) }
  let(:staging_project) { staging_workflow.staging_projects.first }
  let(:source_project) { create(:project, name: 'source_project') }
  let(:target_package) { create(:package, name: 'target_package', project: project) }
  let(:source_package) { create(:package, name: 'source_package', project: source_project) }
  let(:bs_request) do
    create(:bs_request_with_submit_action,
           request_state: 'review',
           target_project: project.name,
           target_package: target_package.name,
           source_project: source_project.name,
           source_package: source_package.name)
  end

  describe '#unassigned_requests' do
    subject { staging_workflow.unassigned_requests }

    context 'without requests in the main project' do
      it { expect(subject).to be_empty }
    end

    context 'with requests but not in staging projects' do
      before { bs_request }

      it { expect(subject).to contain_exactly(bs_request) }
    end

    context 'with requests but all of them are in staging projects' do
      before do
        bs_request.staging_project = staging_project
        bs_request.save
      end

      it { expect(subject).to be_empty }
    end

    context 'with requests and some are in staging projects and some not' do
      let!(:bs_request_2) do
        create(:bs_request_with_submit_action,
               target_project: project.name,
               target_package: target_package.name,
               source_project: source_project.name,
               source_package: source_package.name)
      end

      before do
        bs_request.staging_project = staging_project
        bs_request.save
      end

      it { expect(subject).to contain_exactly(bs_request_2) }
    end
  end

  describe '#ready_requests' do
    subject { staging_workflow.ready_requests }

    context 'without requests in the main project' do
      it { expect(subject).to be_empty }
    end

    context 'with requests but not in state new' do
      before { bs_request }

      it { expect(subject).to be_empty }
    end

    context 'with requests and some are in staging projects and some not' do
      let!(:bs_request_2) do
        create(:bs_request_with_submit_action,
               target_project: project.name,
               target_package: target_package.name,
               source_project: source_project.name,
               source_package: source_package.name)
      end

      before do
        bs_request.staging_project = staging_project
        bs_request.save
      end

      it { expect(subject).to contain_exactly(bs_request_2) }
    end
  end
end
