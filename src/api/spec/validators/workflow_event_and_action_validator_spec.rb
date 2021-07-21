require 'rails_helper'

RSpec.describe WorkflowEventAndActionValidator do
  let(:workflow) do
    { 'steps' => [{ 'branch_package' => { 'source_project' => 'OBS:Server:Unstable', 'source_package' => 'obs-server' } }],
      'filters' => { 'architectures' => { 'only' => ['x86_64'] }, 'repositories' => { 'only' => ['openSUSE_Factory', 'openSUSE_15.1', 'SLE_15_SP1', 'SLE_15_SP3'] } } }
  end
  let(:scm_extractor_payload) do
    {
      scm: scm,
      event: event,
      action: action
    }
  end
  let(:token) { create(:workflow_token, user: create(:confirmed_user, :with_home, login: 'Iggy')) }

  let(:fake_model) do
    Struct.new(:workflow, :scm_extractor_payload, :token) do
      include ActiveModel::Validations

      validates_with WorkflowEventAndActionValidator
    end
  end

  describe '#updated_pull_request' do
    subject { described_class.new({ scm_extractor_payload: scm_extractor_payload }).updated_pull_request? }

    context 'when the SCM is unsupported' do
      let(:scm) { 'GitHoob' }
      let(:event) { 'pull_request' }
      let(:action) { 'updated' }

      it { expect(subject).to be false }
    end

    context 'when the SCM is GitHub' do
      let(:scm) { 'github' }

      context 'for an unsupported event' do
        let(:event) { 'something' }
        let(:action) { 'opened' }

        it { expect(subject).to be false }
      end

      context 'for an updated pull_request event' do
        let(:event) { 'pull_request' }
        let(:action) { 'synchronize' }

        it { expect(subject).to be true }
      end

      context 'for a pull_request event with an unsupported action' do
        let(:event) { 'pull_request' }
        let(:action) { 'something' }

        it { expect(subject).to be false }
      end
    end

    context 'when the SCM is GitLab' do
      let(:scm) { 'gitlab' }

      context 'for an unsupported event' do
        let(:event) { 'something' }
        let(:action) { 'open' }

        it { expect(subject).to be false }
      end

      context 'for an updated merge request event' do
        let(:event) { 'Merge Request Hook' }
        let(:action) { 'update' }

        it { expect(subject).to be true }
      end

      context 'for a merge request event with an unsupported action' do
        let(:event) { 'Merge Request Hook' }
        let(:action) { 'something' }

        it { expect(subject).to be false }
      end
    end
  end

  describe '#validate' do
    subject { fake_model.new(workflow, scm_extractor_payload, token) }

    context 'when the SCM is unsupported' do
      let(:scm) { 'GitHoob' }
      let(:event) { 'pull_request' }
      let(:action) { 'opened' }

      it { expect(subject).not_to be_valid }
    end

    context 'when the SCM is GitHub' do
      let(:scm) { 'github' }

      context 'for a new pull request event' do
        let(:event) { 'pull_request' }
        let(:action) { 'opened' }

        it { expect(subject).to be_valid }
      end

      context 'for an updated_pull_request event' do
        let(:event) { 'pull_request' }
        let(:action) { 'synchronize' }

        it { expect(subject).to be_valid }
      end

      context 'for a pull_request event with an unsupported action' do
        let(:event) { 'pull_request' }
        let(:action) { 'something' }

        it { expect(subject).not_to be_valid }
      end

      context 'for an unsupported event' do
        let(:event) { 'something' }
        let(:action) { 'opened' }

        it { expect(subject).not_to be_valid }
      end
    end

    context 'when the SCM is GitLab' do
      let(:scm) { 'gitlab' }

      context 'for a new merge request event' do
        let(:event) { 'Merge Request Hook' }
        let(:action) { 'open' }

        it { expect(subject).to be_valid }
      end

      context 'for an updated_merge_request event' do
        let(:event) { 'Merge Request Hook' }
        let(:action) { 'update' }

        it { expect(subject).to be_valid }
      end

      context 'for a merge_request event with an unsupported action' do
        let(:event) { 'Merge Request Hook' }
        let(:action) { 'something' }

        it { expect(subject).not_to be_valid }
      end

      context 'for an unsupported event' do
        let(:event) { 'something' }
        let(:action) { 'open' }

        it { expect(subject).not_to be_valid }
      end
    end
  end
end
