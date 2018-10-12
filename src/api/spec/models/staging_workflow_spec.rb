require 'rails_helper'

RSpec.describe StagingWorkflow, type: :model do
  let(:project) { create(:project_with_package) }
  let!(:staging_workflow) { create(:staging_workflow_with_staging_projects, project: project) }

  let(:target_project) { create(:project, name: 'target_project') }
  let(:source_project) { create(:project, name: 'source_project') }
  let(:target_package) { create(:package, name: 'target_package', project: target_project) }
  let(:source_package) { create(:package, name: 'source_package', project: source_project) }
  let(:bs_request) do
    create(:bs_request_with_submit_action,
           target_project: target_project.name,
           target_package: target_package.name,
           source_project: source_project.name,
           source_package: source_package.name)
  end

  it { is_expected.to validate_presence_of :project_id }

  describe '#unassigned_request' do
    subject { staging_workflow.unassigned_requests }

    context 'without requests in the main project' do
      it { expect(subject).to be_empty }
    end

    context 'with requests but not in staging projects' do
      before do
        project.bs_requests << bs_request
        project.save
      end

      it { expect(subject).not_to be_empty }
    end

    context 'with requests but all of them are in staging projects' do
      let!(:staging_project) { staging_workflow.staging_projects.first }

      before do
        project.bs_requests << bs_request
        project.save
        staging_project.bs_requests << bs_request
        staging_project.save
      end

      it { expect(subject).to be_empty }
    end

    context 'with requests and some are in staging projects and some not' do
      let!(:staging_project) { staging_workflow.staging_projects.first }
      let(:bs_request_2) do
        create(:bs_request_with_submit_action,
               target_project: target_project.name,
               target_package: target_package.name,
               source_project: source_project.name,
               source_package: source_package.name)
      end

      before do
        project.bs_requests << bs_request
        project.bs_requests << bs_request_2
        project.save
        staging_project.bs_requests << bs_request
        staging_project.save
      end

      it { expect(subject).not_to be_empty }
    end
  end
end
