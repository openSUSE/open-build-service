require 'rails_helper'

RSpec.describe ScmWebhookEventValidator do
  let(:fake_model) do
    Struct.new(:payload) do
      include ActiveModel::Validations

      validates_with ScmWebhookEventValidator
    end
  end

  let(:payload) do
    {
      scm: scm,
      event: event,
      action: action
    }
  end

  describe '#validate' do
    subject { fake_model.new(payload) }

    context 'when the SCM is unsupported' do
      let(:scm) { 'GitHoob' }
      let(:event) { 'pull_request' }
      let(:action) { 'updated' }

      it 'is not valid and has an error message' do
        subject.valid?
        expect(subject.errors.full_messages.to_sentence).to eq('Event not supported.')
      end
    end

    context 'when the SCM is GitHub' do
      let(:scm) { 'github' }

      context 'for an unsupported event' do
        let(:event) { 'something' }
        let(:action) { 'opened' }

        it 'is not valid and has an error message' do
          subject.valid?
          expect(subject.errors.full_messages.to_sentence).to eq('Event not supported.')
        end
      end

      context 'for a pull request with an unsupported action' do
        let(:event) { 'pull_request' }
        let(:action) { 'something' }

        it 'is not valid and has an error message' do
          subject.valid?
          expect(subject.errors.full_messages.to_sentence).to eq('Pull request action not supported.')
        end
      end

      context 'for a new pull request' do
        let(:event) { 'pull_request' }
        let(:action) { 'opened' }

        it { is_expected.to be_valid }
      end

      context 'for a pull request which was updated' do
        let(:event) { 'pull_request' }
        let(:action) { 'synchronize' }

        it { is_expected.to be_valid }
      end

      context 'for a pull request which was closed/merged' do
        let(:event) { 'pull_request' }
        let(:action) { 'closed' }

        it { is_expected.to be_valid }
      end

      context 'for a pull request which was reopened' do
        let(:event) { 'pull_request' }
        let(:action) { 'reopened' }

        it { is_expected.to be_valid }
      end
    end

    context 'when the SCM is GitLab' do
      let(:scm) { 'gitlab' }

      context 'for an unsupported event' do
        let(:event) { 'something' }
        let(:action) { 'open' }

        it 'is not valid and has an error message' do
          subject.valid?
          expect(subject.errors.full_messages.to_sentence).to eq('Event not supported.')
        end
      end

      context 'for a merge request with an unsupported action' do
        let(:event) { 'Merge Request Hook' }
        let(:action) { 'something' }

        it 'is not valid and has an error message' do
          subject.valid?
          expect(subject.errors.full_messages.to_sentence).to eq('Merge request action not supported.')
        end
      end

      context 'for a new merge request' do
        let(:event) { 'Merge Request Hook' }
        let(:action) { 'open' }

        it { is_expected.to be_valid }
      end

      context 'for a merge request which was updated' do
        let(:event) { 'Merge Request Hook' }
        let(:action) { 'update' }

        it { is_expected.to be_valid }
      end

      context 'for a merge request which was closed' do
        let(:event) { 'Merge Request Hook' }
        let(:action) { 'close' }

        it { is_expected.to be_valid }
      end

      context 'for a merge request which was merged' do
        let(:event) { 'Merge Request Hook' }
        let(:action) { 'merge' }

        it { is_expected.to be_valid }
      end

      context 'for a merge request which was reopened' do
        let(:event) { 'Merge Request Hook' }
        let(:action) { 'reopen' }

        it { is_expected.to be_valid }
      end
    end
  end
end
