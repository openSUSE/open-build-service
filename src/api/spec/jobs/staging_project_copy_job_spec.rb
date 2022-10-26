require 'rails_helper'
require 'webmock/rspec'

RSpec.describe StagingProjectCopyJob, vcr: true do
  include ActiveJob::TestHelper

  describe '#perform' do
    let(:user) { create(:confirmed_user, :with_home) }
    let(:staging_workflow) { create(:staging_workflow, project: user.home_project) }
    let!(:original_staging_project) { create(:staging_project, staging_workflow: staging_workflow, project_config: 'Prefer: something') }
    let(:staging_project_copy_name) { "#{original_staging_project.name}-copy" }

    it 'copies the staging project' do
      expect(Project.exists?(name: staging_project_copy_name)).to be false
      StagingProjectCopyJob.perform_now(staging_workflow.project.name, original_staging_project.name, staging_project_copy_name, user.id)
      expect(Project.exists?(name: staging_project_copy_name)).to be true
    end
  end
end
