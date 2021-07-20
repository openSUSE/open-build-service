require 'rails_helper'

RSpec.describe Token::Workflow, vcr: true do
  let(:token_user) { create(:confirmed_user, :with_home, login: 'Iggy') }
  let(:workflow_token) { create(:workflow_token, user: token_user) }
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
          ref: 'main'
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
        http_url: 'https://gitlab.com/eduardoj2/test.git'
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

  RSpec.shared_context 'successful workflow call' do
    it 'creates a new branched project with PR suffix' do
      token_user.run_as do
        expect { subject }.to change(Project.where('name LIKE ?', '%:PR-%'), :count)
      end
    end

    it 'creates a new Event::BuildSuccess subscription' do
      token_user.run_as do
        expect { subject }.to change(EventSubscription.where(eventtype: 'Event::BuildSuccess', channel: 'scm'), :count)
      end
    end

    it 'creates a new Event::BuildFail subscription' do
      token_user.run_as do
        expect { subject }.to change(EventSubscription.where(eventtype: 'Event::BuildFail', channel: 'scm'), :count)
      end
    end
  end

  describe '#call' do
    context "when the webhook's event is not the expected one" do
      context 'when the SCM is GitHub' do
        it_behaves_like 'not-allowed event or action' do
          let(:scm) { 'github' }
          let(:event) { 'push' }
          let(:payload) { github_payload }
        end
      end

      context 'when the SCM is GitLab' do
        it_behaves_like 'not-allowed event or action' do
          let(:scm) { 'gitlab' }
          let(:event) { 'Push Hook' }
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

    context 'when the step is not valid' do
      let(:scm) { 'github' }
      let(:event) { 'pull_request' }
      let(:payload) { github_payload }
      let(:invalid_steps_workflows_yml_file) { File.expand_path(Rails.root.join('spec/support/files/invalid_steps_workflows.yml')) }
      let(:downloader) { instance_double(Workflows::YAMLDownloader) }

      before do
        allow(Workflows::YAMLDownloader).to receive(:new).and_return(downloader)
        allow(downloader).to receive(:call).and_return(invalid_steps_workflows_yml_file)
      end

      it 'raises an "Invalid workflow step definition" error' do
        expect { subject }.to raise_error(Token::Errors::InvalidWorkflowStepDefinition)
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
      let(:project) { create(:project, name: 'test-project', maintainer: workflow_token.user) }
      let!(:package) { create(:package, name: 'test-package', project: project) }
      let(:workflows_yml_file) { File.expand_path(Rails.root.join('spec/support/files/workflows.yml')) }
      let(:downloader) { instance_double(Workflows::YAMLDownloader) }
      let(:reporter) { instance_double(SCMStatusReporter) }

      before do
        # Stub Workflows::YAMLDownloader#call
        allow(Workflows::YAMLDownloader).to receive(:new).and_return(downloader)
        allow(downloader).to receive(:call).and_return(workflows_yml_file)
        # Stub SCMStatusReporter#call
        allow(SCMStatusReporter).to receive(:new).and_return(reporter)
        allow(reporter).to receive(:call)
      end

      context 'when the SCM is GitHub' do
        it_behaves_like 'successful workflow call' do
          let(:scm) { 'github' }
          let(:event) { 'pull_request' }
          let(:payload) { github_payload }
        end
      end

      context 'when the SCM is GitLab' do
        it_behaves_like 'successful workflow call' do
          let(:scm) { 'gitlab' }
          let(:event) { 'Merge Request Hook' }
          let(:payload) { gitlab_payload }
        end
      end
    end
  end
end
