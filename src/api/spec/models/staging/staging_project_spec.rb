require 'rails_helper'
require 'webmock/rspec'

RSpec.describe Staging::StagingProject, vcr: true do
  let(:user) { create(:confirmed_user, login: 'tom') }
  let(:staging_workflow) { create(:staging_workflow_with_staging_projects, project: user.home_project) }
  let(:staging_project) { staging_workflow.staging_projects.first }

  let!(:repository) { create(:repository, architectures: ['x86_64'], project: staging_project, name: 'staging_repository') }
  let!(:package) { create(:package_with_file, project: staging_project) }

  let!(:status_report) { create(:status_report, checkable: repository) }

  let(:target_project) { create(:project, name: 'target_project') }
  let(:source_project) { create(:project, name: 'source_project') }
  let(:target_package) { create(:package, name: 'target_package', project: target_project) }
  let(:source_package) { create(:package, name: 'source_package', project: source_project) }

  let(:request_attributes) do
    {
      target_project: target_project.name,
      target_package: target_package.name,
      source_project: source_project.name,
      source_package: source_package.name
    }
  end

  let!(:submit_request) { create(:bs_request_with_submit_action, request_attributes.merge(staging_project: staging_project)) }

  before do
    allow(Backend::Api::Published).to receive(:build_id).with(staging_project.name, repository.name).and_return('1234')
    status_report.update(uuid: '1234')
  end

  describe '#staging_identifier' do
    before do
      staging_project.update(name: 'openSUSE_41:Staging:myStagingProject')
    end

    it { expect(staging_project.staging_identifier).to eq('myStagingProject') }
  end

  describe '#untracked_requests' do
    let!(:request_with_review) do
      create(:review_bs_request_by_project, request_attributes.merge(reviewer: user, review_by_project: staging_project))
    end

    it { expect(staging_project.untracked_requests).to contain_exactly(request_with_review) }
  end

  describe '#overall_state' do
    before do
      User.current = user
    end

    context 'when there are no staged requests' do
      before do
        submit_request.destroy
      end

      it { expect(staging_project.overall_state).to eq(:empty) }
    end

    context 'when request got revoked' do
      before do
        submit_request.update(state: 'revoked')
      end

      it { expect(staging_project.overall_state).to eq(:unacceptable) }
    end

    context 'when there are missing checks' do
      before do
        repository.update(required_checks: ['check_1'])
      end

      it { expect(staging_project.overall_state).to eq(:testing) }
    end

    context 'when there are pending checks' do
      let!(:check) { create(:check, name: 'check_1', status_report: status_report, state: 'pending') }

      it { expect(staging_project.overall_state).to eq(:testing) }
    end

    context 'when there are failed checks' do
      let!(:check) { create(:check, name: 'check_1', status_report: status_report, state: 'failure') }

      it { expect(staging_project.overall_state).to eq(:failed) }
    end
  end
end
