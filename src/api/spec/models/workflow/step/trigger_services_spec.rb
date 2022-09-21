require 'rails_helper'

RSpec.describe Workflow::Step::TriggerServices do
  let!(:user) { create(:confirmed_user, :with_home, login: 'Iggy') }
  let(:token) { create(:workflow_token, executor: user) }
  let(:project) { create(:project, name: 'openSUSE:Factory', maintainer: user) }
  let(:package) { create(:package, name: 'hello_world', project: project) }

  let(:step_instructions) { { package: package.name, project: project.name } }

  let(:scm_webhook) do
    SCMWebhook.new(payload: {
                     scm: 'github',
                     event: 'pull_request',
                     action: 'opened',
                     pr_number: 1,
                     source_repository_full_name: 'reponame',
                     commit_sha: '123'
                   })
  end

  subject do
    described_class.new(step_instructions: step_instructions,
                        scm_webhook: scm_webhook,
                        token: token)
  end

  describe '#call' do
    context 'user has no permission to trigger the services' do
      let(:another_user) { create(:confirmed_user, :with_home, login: 'Oggy') }
      let!(:token) { create(:workflow_token, executor: another_user) }

      it { expect { subject.call }.to raise_error(Pundit::NotAuthorizedError) }
    end

    context 'user has permission to trigger the services' do
      let(:comment) { 'Service triggered by a workflow token via Github PR/MR #1 (pull_request).' }

      before do
        allow(Backend::Api::Sources::Package).to receive(:trigger_services).and_return(true)
      end

      it 'triggers the service on the backend' do
        subject.call
        expect(Backend::Api::Sources::Package).to have_received(:trigger_services).with('openSUSE:Factory', 'hello_world', 'Iggy', comment)
      end
    end
  end
end
