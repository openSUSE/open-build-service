RSpec.describe Workflow::Step::RebuildPackage, :vcr do
  subject do
    described_class.new(step_instructions: step_instructions,
                        token: token,
                        workflow_run: workflow_run)
  end

  let!(:user) { create(:confirmed_user, :with_home, login: 'Iggy') }
  let(:token) { create(:workflow_token, executor: user) }
  let(:project) { create(:project, name: 'openSUSE:Factory', maintainer: user) }
  let(:package) { create(:package, name: 'hello_world', project: project) }

  let!(:repository) { create(:repository, project: project, rebuild: 'direct', name: 'repository_1', architectures: ['x86_64']) }

  let(:step_instructions) { { package: package.name, project: project.name } }

  let(:request_payload) { file_fixture('request_payload_github_pull_request_opened.json').read }

  let(:workflow_run) do
    create(:workflow_run, scm_vendor: 'github', hook_event: 'pull_request', request_payload: request_payload)
  end

  before do
    project.store
  end

  it { expect { subject.call }.not_to raise_error }

  context 'user has no permission to trigger rebuild' do
    let(:another_user) { create(:confirmed_user, :with_home, login: 'Oggy') }
    let!(:token) { create(:workflow_token, executor: another_user) }

    it { expect { subject.call }.to raise_error(Pundit::NotAuthorizedError) }
  end
end
