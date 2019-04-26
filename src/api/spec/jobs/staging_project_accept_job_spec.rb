require 'rails_helper'
require 'webmock/rspec'

RSpec.describe StagingProjectAcceptJob, type: :job do
  include ActiveJob::TestHelper

  describe '#perform' do
    let(:user) { create(:confirmed_user, login: 'tom') }
    let(:managers_group) { create(:group) }
    let(:staging_workflow) { create(:staging_workflow_with_staging_projects, project: user.home_project, managers_group: managers_group) }
    let(:staging_project) { staging_workflow.staging_projects.first }
    let(:project_double) { instance_double(Project) }

    subject { StagingProjectAcceptJob.perform_now(project_id: staging_project.id, user_login: user.login) }

    before do
      allow(Project).to receive(:find).and_return(project_double)
      allow(project_double).to receive(:accept)
      subject
    end

    it { expect(project_double).to have_received(:accept) }
  end
end
