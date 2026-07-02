RSpec.describe Workflow::Step::LinkProject do
  subject do
    described_class.new(step_instructions: step_instructions,
                        token: token,
                        workflow_run: workflow_run)
  end

  let(:user) { create(:confirmed_user, :with_home, login: 'Iggy') }
  let(:token) { create(:workflow_token, executor: user) }
  let!(:source_project) { create(:project, name: 'source_project', maintainer: user) }
  let!(:target_project) { create(:project, name: 'target_project', maintainer: user) }
  let(:step_instructions) do
    {
      target_project: target_project.name,
      source_project: source_project.name
    }
  end

  let(:hook_event) { 'pull_request' }
  let(:hook_action) { 'opened' }
  let(:request_payload) { file_fixture('request_payload_github_pull_request_opened.json').read }
  let(:workflow_run) do
    create(:workflow_run, scm_vendor: 'github', hook_event: hook_event, hook_action: hook_action, request_payload: request_payload)
  end

  before do
    login(user)
  end

  describe '#validate_existence_of_projects' do
    before do
      create(:project, name: subject.target_project_name)
    end

    context 'when both projects exist' do
      it 'is valid' do
        expect(subject).to be_valid
      end
    end

    context 'when the source project does not exist' do
      let(:step_instructions) do
        {
          target_project: target_project.name,
          source_project: 'does_not_exist'
        }
      end

      it 'is invalid' do
        expect(subject).not_to be_valid
      end

      it 'adds an error' do
        subject.valid?
        expect(subject.errors.full_messages).to include("The project 'does_not_exist' does not exist.")
      end
    end

    context 'when the source project is a remote project' do
      let!(:interconnect) { create(:remote_project, name: 'remote_obs') }
      let(:step_instructions) do
        {
          target_project: target_project.name,
          source_project: 'remote_obs:remote_project'
        }
      end

      before do
        allow(Project).to receive(:exists_by_name).and_call_original
        allow(Project).to receive(:exists_by_name).with('remote_obs:remote_project').and_return(true)
      end

      it 'is valid' do
        expect(subject).to be_valid
      end
    end
  end

  describe '#call' do
    context 'when a required key is missing' do
      let(:step_instructions) { { target_project: source_project.name } }

      it 'does not change any project link' do
        expect { subject.call }.not_to change(LinkedProject, :count)
      end
    end

    context 'when adding a link' do
      shared_examples 'an scm event that adds a project link' do
        it 'creates a LinkedProject' do
          expect { subject.call }.to change(LinkedProject, :count).by(1)
        end

        it 'links the source project to the target project' do
          subject.call
          expect(subject.target_project.reload.projects_linking_to).to include(source_project)
        end
      end

      context 'for a new pull request' do
        before do
          create(:project, name: subject.target_project_name)
        end

        let(:hook_action) { 'opened' }

        it_behaves_like 'an scm event that adds a project link'
      end

      context 'for a reopened pull request' do
        before do
          create(:project, name: subject.target_project_name)
        end

        let(:hook_action) { 'reopened' }

        it_behaves_like 'an scm event that adds a project link'
      end

      context 'for a labeled pull request' do
        before do
          create(:project, name: subject.target_project_name)
        end

        let(:hook_action) { 'labeled' }
        let(:request_payload) { file_fixture('request_payload_github_pull_request_labeled.json').read }

        it_behaves_like 'an scm event that adds a project link'
      end

      context 'for a push event' do
        let(:hook_event) { 'push' }
        let(:hook_action) { nil }
        let(:request_payload) { file_fixture('request_payload_github_push.json').read }

        it_behaves_like 'an scm event that adds a project link'
      end

      context 'for a tag push event' do
        let(:hook_event) { 'push' }
        let(:hook_action) { nil }
        let(:request_payload) { file_fixture('request_payload_github_tag_push.json').read }

        it_behaves_like 'an scm event that adds a project link'
      end
    end

    context 'when removing a link' do
      before do
        create(:project, name: subject.target_project_name)
        subject.target_project.add_project_link(source_project_name: source_project.name)
      end

      shared_examples 'an scm event that removes a project link' do
        it 'removes the LinkedProject' do
          expect { subject.call }.to change(LinkedProject, :count).by(-1)
        end

        it 'unlinks the source project from the target project' do
          subject.call
          expect(source_project.reload.projects_linking_to).not_to include(target_project)
        end
      end

      context 'for a closed/merged pull request' do
        let(:hook_action) { 'closed' }
        let(:request_payload) { file_fixture('request_payload_github_pull_request_closed.json').read }

        it_behaves_like 'an scm event that removes a project link'
      end

      context 'for an unlabeled pull request' do
        let(:hook_action) { 'unlabeled' }
        let(:request_payload) { file_fixture('request_payload_github_pull_request_unlabeled.json').read }

        it_behaves_like 'an scm event that removes a project link'
      end
    end
  end
end
