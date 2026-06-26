RSpec.describe Workflow::Step::TriggerServices do
  subject do
    described_class.new(step_instructions: step_instructions,
                        token: token,
                        workflow_run: workflow_run)
  end

  let!(:user) { create(:confirmed_user, :with_home, login: 'Iggy') }
  let(:token) { create(:workflow_token, executor: user) }
  let(:project) { create(:project, name: 'openSUSE:Factory', maintainer: user) }
  let(:package) { create(:package, name: 'hello_world', project: project) }

  let(:step_instructions) { { package: package.name, project: project.name } }
  let(:request_payload) { file_fixture('request_payload_github_pull_request_opened.json').read }

  let(:workflow_run) do
    create(:workflow_run, scm_vendor: 'github', hook_event: 'pull_request', request_payload: request_payload)
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
