require 'rails_helper'
require 'webmock/rspec'

RSpec.describe StagingProjectCopyJob, type: :job, vcr: true do
  include ActiveJob::TestHelper

  describe '#perform' do
    let(:user) { create(:confirmed_user) }
    let(:staging_workflow) { create(:staging_workflow, project: user.home_project) }
    let!(:original_staging_project) { create(:staging_project, staging_workflow: staging_workflow, project_config: 'Prefer: something') }
    let(:staging_project_copy_name) { "#{original_staging_project.name}-copy" }

    it 'copies the staging project' do
      expect(Project.exists?(name: staging_project_copy_name)).to be false
      StagingProjectCopyJob.perform_now(staging_workflow.project.name, original_staging_project.name, staging_project_copy_name, user.id)
      expect(Project.exists?(name: staging_project_copy_name)).to be true
    end

    context 'when a user session already exists for another user' do
      let(:other_user) { create(:confirmed_user) }

      before do
        User.session = other_user
      end

      subject do
        StagingProjectCopyJob.perform_now(staging_workflow.project.name, original_staging_project.name,
                                          "#{other_user.home_project_name}:subproject", user.id)
      end

      it 'does not use the existing session' do
        expect { subject }.to raise_error Project::Errors::WritePermissionError,
                                          "No permission to modify project '#{other_user.home_project_name}:subproject' for user '#{user.login}'"
      end
    end
  end
end
