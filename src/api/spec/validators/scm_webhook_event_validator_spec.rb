require 'rails_helper'

RSpec.describe SCMWebhookEventValidator do
  let(:fake_model) do
    Struct.new(:payload) do
      include ActiveModel::Validations

      validates_with SCMWebhookEventValidator
    end
  end

  describe '#validate' do
    subject { fake_model.new(payload) }

    context 'when the SCM is unsupported' do
      let(:payload) { { scm: 'GitHoob', event: 'pull_request', action: 'updated' } }

      it 'is not valid and has an error message' do
        subject.valid?
        expect(subject.errors.full_messages.to_sentence).to eq('Event not supported.')
      end
    end

    context 'when the SCM is GitHub' do
      context 'for an unsupported event' do
        let(:payload) { { scm: 'github', event: 'something', action: 'opened' } }

        it 'is not valid and has an error message' do
          subject.valid?
          expect(subject.errors.full_messages.to_sentence).to eq('Event not supported.')
        end
      end

      context 'for a pull request with an unsupported action' do
        let(:payload) { { scm: 'github', event: 'pull_request', action: 'something' } }

        it 'is not valid and has an error message' do
          subject.valid?
          expect(subject.errors.full_messages.to_sentence).to eq('Pull request action not supported.')
        end
      end

      context 'for a new pull request' do
        let(:payload) { { scm: 'github', event: 'pull_request', action: 'opened' } }

        it { is_expected.to be_valid }
      end

      context 'for a pull request which was updated' do
        let(:payload) { { scm: 'github', event: 'pull_request', action: 'synchronize' } }

        it { is_expected.to be_valid }
      end

      context 'for a pull request which was closed/merged' do
        let(:payload) { { scm: 'github', event: 'pull_request', action: 'closed' } }

        it { is_expected.to be_valid }
      end

      context 'for a pull request which was reopened' do
        let(:payload) { { scm: 'github', event: 'pull_request', action: 'reopened' } }

        it { is_expected.to be_valid }
      end

      context 'for a push event with a non-valid branch/tag reference' do
        let(:payload) { { scm: 'github', event: 'push', ref: 'something' } }

        it 'is not valid and has an error message' do
          subject.valid?
          expect(subject.errors.full_messages.to_sentence).to eq('Push event supported only for branches/tags with a valid reference.')
        end
      end

      context 'for a push event with a valid branch reference' do
        let(:payload) { { scm: 'github', event: 'push', ref: 'refs/heads/master' } }

        it { is_expected.to be_valid }
      end

      context 'for a push event with a valid tag reference' do
        let(:payload) { { scm: 'github', event: 'push', ref: 'refs/tags/release_abc' } }

        it { is_expected.to be_valid }
      end
    end

    context 'when the SCM is GitLab' do
      context 'for an unsupported event' do
        let(:payload) { { scm: 'gitlab', event: 'something', action: 'open' } }

        it 'is not valid and has an error message' do
          subject.valid?
          expect(subject.errors.full_messages.to_sentence).to eq('Event not supported.')
        end
      end

      context 'for a merge request with an unsupported action' do
        let(:payload) { { scm: 'gitlab', event: 'Merge Request Hook', action: 'something' } }

        it 'is not valid and has an error message' do
          subject.valid?
          expect(subject.errors.full_messages.to_sentence).to eq('Merge request action not supported.')
        end
      end

      context 'for a new merge request' do
        let(:payload) { { scm: 'gitlab', event: 'Merge Request Hook', action: 'open' } }

        it { is_expected.to be_valid }
      end

      context 'for a merge request which was updated' do
        let(:payload) { { scm: 'gitlab', event: 'Merge Request Hook', action: 'update' } }

        it { is_expected.to be_valid }
      end

      context 'for a merge request which was closed' do
        let(:payload) { { scm: 'gitlab', event: 'Merge Request Hook', action: 'close' } }

        it { is_expected.to be_valid }
      end

      context 'for a merge request which was merged' do
        let(:payload) { { scm: 'gitlab', event: 'Merge Request Hook', action: 'merge' } }

        it { is_expected.to be_valid }
      end

      context 'for a merge request which was reopened' do
        let(:payload) { { scm: 'gitlab', event: 'Merge Request Hook', action: 'reopen' } }

        it { is_expected.to be_valid }
      end

      context 'for a push event with a non-valid branch reference' do
        let(:payload) { { scm: 'gitlab', event: 'Push Hook', ref: 'something' } }

        it 'is not valid and has an error message' do
          subject.valid?
          expect(subject.errors.full_messages.to_sentence).to eq('Push event supported only for branches/tags with a valid reference.')
        end
      end

      context 'for a push event with a non-valid tag reference' do
        let(:payload) { { scm: 'gitlab', event: 'Tag Push Hook', ref: 'something' } }

        it 'is not valid and has an error message' do
          subject.valid?
          expect(subject.errors.full_messages.to_sentence).to eq('Push event supported only for branches/tags with a valid reference.')
        end
      end

      context 'for a push event which is for a valid branch reference' do
        let(:payload) { { scm: 'gitlab', event: 'Push Hook', ref: 'refs/heads/master' } }

        it { is_expected.to be_valid }
      end

      context 'for a push event which is for a valid tag reference' do
        let(:payload) { { scm: 'gitlab', event: 'Tag Push Hook', ref: 'refs/tags/release_abc' } }

        it { is_expected.to be_valid }
      end
    end
  end
end
