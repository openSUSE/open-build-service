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

  describe '#call' do
    context 'when adding a link' do
      context 'when the target project exists' do
        before do
          create(:project, name: subject.target_project_name)
        end

        let(:hook_action) { 'opened' }

        it 'creates a LinkedProject' do
          expect { subject.call }.to change(LinkedProject, :count).by(1)
        end

        it 'links the source project to the target project' do
          subject.call
          expect(subject.target_project.reload.projects_linking_to).to include(source_project)
        end
      end

      context 'when the target project does not exist' do
        let(:hook_action) { 'opened' }

        it 'creates a LinkedProject' do
          expect { subject.call }.to change(LinkedProject, :count).by(1)
        end

        it 'links the source project to the target project' do
          subject.call
          expect(subject.target_project.reload.projects_linking_to).to include(source_project)
        end
      end
    end

    context 'when removing a link' do
      before do
        create(:project, name: subject.target_project_name)
        subject.target_project.add_project_link(source_project_name: source_project.name)
      end

      let(:hook_action) { 'closed' }
      let(:request_payload) { file_fixture('request_payload_github_pull_request_closed.json').read }

      it 'removes the LinkedProject' do
        expect { subject.call }.to change(LinkedProject, :count).by(-1)
      end

      it 'unlinks the source project from the target project' do
        subject.call
        expect(source_project.reload.projects_linking_to).not_to include(target_project)
      end
    end
  end
end
