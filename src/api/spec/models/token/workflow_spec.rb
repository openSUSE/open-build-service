require 'rails_helper'

RSpec.describe Token::Workflow, vcr: true do
  let(:token_user) { create(:confirmed_user, :with_home, login: 'Iggy') }
  let(:workflow_token) { create(:workflow_token, user: token_user) }
  # TODO: rerun the specs with vcr on to see if we clear some of the cassettes
  let(:github_payload) do
    {
      action: 'opened',
      pull_request: {
        head: {
          repo: {
            full_name: 'username/test_repo'
          }
        },
        base: {
          ref: 'main',
          repo: {
            full_name: 'openSUSE/open-build-service'
          }
        }
      },
      number: 4,
      sender: {
        url: 'https://api.github.com'
      }
    }
  end

  let(:gitlab_payload) do
    {
      object_kind: 'merge_request',
      object_attributes: {
        iid: 3,
        source_branch: 'source',
        target_branch: 'master',
        action: 'open'
      },
      project: {
        http_url: 'https://gitlab.com/eduardoj2/test.git',
        path_with_namespace: 'openSUSE/open-build-service'
      },
      action: 'opened'
    }
  end

  subject { workflow_token.call(scm: scm, event: event, payload: payload) }

  RSpec.shared_context 'not-allowed event or action' do
    it 'returns nothing' do
      expect(subject).to be_nil
    end

    it 'does not create a new branched project with PR suffix' do
      expect { subject }.not_to change(Project.where('name LIKE ?', '%:PR-%'), :count)
    end
  end

  # FIXME: Create a mocked workflow to just test the workflow calling
  describe '#call' do
    context "when the webhook's event is not the expected one" do
      context 'when the SCM is GitHub' do
        it_behaves_like 'not-allowed event or action' do
          let(:scm) { 'github' }
          let(:event) { 'synchronize' }
          let(:payload) { github_payload }
        end
      end

      context 'when the SCM is GitLab' do
        it_behaves_like 'not-allowed event or action' do
          let(:scm) { 'gitlab' }
          let(:event) { 'Issue Hook' }
          let(:payload) { gitlab_payload }
        end
      end
    end

    context "when the webhook's action is not the expected one" do
      context 'when the SCM is GitHub' do
        it_behaves_like 'not-allowed event or action' do
          let(:scm) { 'github' }
          let(:event) { 'pull_request' }
          let(:payload) { { 'action' => 'wrong_action' } }
        end
      end

      context 'when the SCM is GitLab' do
        it_behaves_like 'not-allowed event or action' do
          let(:scm) { 'gitlab' }
          let(:event) { 'Merge Request Hook' }
          let(:payload) { { 'object_attributes' => { 'action' => 'wrong_action' } } }
        end
      end
    end

    context 'when the workflows.yml do not exist on the reference branch' do
      let(:octokit_client) { instance_double(Octokit::Client) }
      let(:scm) { 'github' }
      let(:event) { 'pull_request' }
      let(:payload) { github_payload }
      let(:project) { create(:project, name: 'test-project', maintainer: workflow_token.user) }
      let!(:package) { create(:package, name: 'test-package', project: project) }

      before do
        allow(Octokit::Client).to receive(:new).and_return(octokit_client)
        allow(octokit_client).to receive(:content).and_return({ download_url: 'https://google.com' })
        allow(Down).to receive(:download).and_raise(Down::Error, 'Beep Boop, something is wrong')
      end

      it 'raises a user-friendly error message' do
        expect { subject }.to raise_error(Token::Errors::NonExistentWorkflowsFile,
                                          '.obs/workflows.yml could not be downloaded from the SCM branch main: Beep Boop, something is wrong')
      end
    end

    context 'when the webhook and configuration is correct' do
      let(:scm) { 'github' }
      let(:event) { 'pull_request' }
      let(:payload) { github_payload }
      let(:project) { create(:project, name: 'test-project', maintainer: workflow_token.user) }
      let!(:package) { create(:package, name: 'test-package', project: project) }
      let!(:target_project) { create(:project, name: 'test-target-project', maintainer: workflow_token.user) }
      let(:workflows_yml_file) { File.expand_path(Rails.root.join('spec/support/files/workflows.yml')) }
      let(:downloader) { instance_double(Workflows::YAMLDownloader) }
      let(:reporter) { instance_double(SCMStatusReporter) }
      let(:stubbed_workflow) { instance_double(Workflow) }

      before do
        # Stub Workflows::YAMLDownloader#call
        allow(Workflows::YAMLDownloader).to receive(:new).and_return(downloader)
        allow(downloader).to receive(:call).and_return(workflows_yml_file)
        # Stub SCMStatusReporter#call
        allow(SCMStatusReporter).to receive(:new).and_return(reporter)
        allow(reporter).to receive(:call)
        login token_user
        allow(Workflow).to receive(:new).and_return(stubbed_workflow)
        allow(stubbed_workflow).to receive(:call)
        allow(stubbed_workflow).to receive(:valid?).and_return(true)
      end

      context 'when the SCM is GitHub' do
        let(:scm) { 'github' }
        let(:event) { 'pull_request' }
        let(:payload) { github_payload }

        before { subject }

        it 'runs the workflow' do
          expect(stubbed_workflow).to have_received(:call)
        end
      end

      context 'when the SCM is GitLab' do
        let(:scm) { 'gitlab' }
        let(:event) { 'Merge Request Hook' }
        let(:payload) { gitlab_payload }

        before { subject }

        it 'runs the workflow' do
          expect(stubbed_workflow).to have_received(:call)
        end
      end
    end
  end
end
