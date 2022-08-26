require 'rails_helper'

RSpec.describe ProjectPolicy, vcr: true do
  subject { ProjectPolicy }

  context 'staging' do
    let(:unauthorized_user) { create(:confirmed_user, login: 'Henne') }
    let(:staging_manager) { create(:confirmed_user, login: 'Dominique') }
    let(:group) { create(:group, title: 'factory-staging', users: [staging_manager]) }
    let(:code_stream_manager) { create(:confirmed_user, login: 'Rudi') }
    let(:release_manager) do
      release_manager = create(:confirmed_user, login: 'Max')
      create(:relationship_project_user,
             user: release_manager,
             project: staging_project)
      release_manager
    end
    let(:source_project) { create(:project, name: 'devel:base') }
    let(:source_package) { create(:package_with_file, name: 'aaa_base', project: source_project) }
    let(:target_project) { create(:project_with_package, name: 'openSUSE:Factory', package_name: 'aaa_base', maintainer: code_stream_manager) }
    let(:staging_workflow) do
      workflow = create(:staging_workflow, project: target_project, managers_group: group)
      submit_request = create(:bs_request_with_submit_action, target_project: target_project,
                                                              target_package: 'aaa_base',
                                                              source_project: source_project.name,
                                                              source_package: source_package.name)
      submit_request.reviews.map { |review| review.update(state: 'accepted') }
      submit_request.update(state: 'new')
      workflow.staging_projects.first.staged_requests << submit_request

      workflow
    end
    let(:staging_project) { staging_workflow.staging_projects.first }

    permissions :accept? do
      it 'deny without write access to staging project' do
        expect(subject).not_to permit(unauthorized_user, staging_project)
      end

      it 'deny without write access to target project' do
        expect { subject.new(release_manager, staging_project).accept? }
          .to raise_error(an_instance_of(Pundit::NotAuthorizedError).and(having_attributes(reason: :request_state_change)))
      end

      it 'deny with approver that has no write access to target project' do
        staging_workflow.staged_requests.map { |bs_request| bs_request.update(approver: unauthorized_user) }
        expect { subject.new(release_manager, staging_project).accept? }
          .to raise_error(an_instance_of(Pundit::NotAuthorizedError).and(having_attributes(reason: :request_state_change)))
      end

      it 'permit with write access to staging project and target project' do
        create(:relationship_project_user,
               user: code_stream_manager,
               project: staging_project)
        expect(subject).to permit(code_stream_manager, staging_project)
      end

      it 'permit without write access to target project and pre approved requests' do
        staging_workflow.staged_requests.map { |bs_request| bs_request.update(approver: code_stream_manager) }
        expect(subject).to permit(release_manager, staging_project)
      end
    end
  end
end
