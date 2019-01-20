require 'rails_helper'
require 'webmock/rspec'

RSpec.describe StagingProjectCopyJob, type: :job, vcr: true do
  include ActiveJob::TestHelper

  describe '#perform' do
    let(:project) { create(:project, name: 'my_project') }
    let(:staging_workflow) { create(:staging_workflow, project: project) }
    let!(:original_staging_project) { create(:staging_project, staging_workflow: staging_workflow, project_config: 'Prefer: something') }
    let(:staging_project_copy_name) { "#{original_staging_project.name}-copy" }

    it 'copies the staging project' do
      expect(Project.exists?(name: staging_project_copy_name)).to be false
      StagingProjectCopyJob.new.perform(staging_workflow.project.name, original_staging_project.name, staging_project_copy_name)
      expect(Project.exists?(name: staging_project_copy_name)).to be true
    end
  end
end
