require 'rails_helper'

RSpec.describe ScmWebhook, type: :model do
  describe '#new_pull_request?' do
    subject { described_class.new(payload: payload).new_pull_request? }

    context 'for an unsupported SCM' do
      let(:payload) { { scm: 'GitHoob', event: 'pull_request', action: 'opened' } }

      it { is_expected.to be false }
    end

    context 'for an unsupported event from GitHub' do
      let(:payload) { { scm: 'github', event: 'something', action: 'opened' } }

      it { is_expected.to be false }
    end

    context 'for an unsupported action from GitHub' do
      let(:payload) { { scm: 'github', event: 'pull_request', action: 'something' } }

      it { is_expected.to be false }
    end

    context 'for a new pull request from GitHub' do
      let(:payload) { { scm: 'github', event: 'pull_request', action: 'opened' } }

      it { is_expected.to be true }
    end

    context 'for an unsupported event from GitLab' do
      let(:payload) { { scm: 'gitlab', event: 'something', action: 'open' } }

      it { is_expected.to be false }
    end

    context 'for an unsupported action from GitLab' do
      let(:payload) { { scm: 'gitlab', event: 'Merge Request Hook', action: 'something' } }

      it { is_expected.to be false }
    end

    context 'for a new merge request from GitLab' do
      let(:payload) { { scm: 'gitlab', event: 'Merge Request Hook', action: 'open' } }

      it { is_expected.to be true }
    end
  end

  describe '#updated_pull_request?' do
    subject { described_class.new(payload: payload).updated_pull_request? }

    context 'for an unsupported SCM' do
      let(:payload) { { scm: 'GitHoob', event: 'pull_request', action: 'synchronize' } }

      it { is_expected.to be false }
    end

    context 'for an unsupported event from GitHub' do
      let(:payload) { { scm: 'github', event: 'something', action: 'synchronize' } }

      it { is_expected.to be false }
    end

    context 'for an unsupported action from GitHub' do
      let(:payload) { { scm: 'github', event: 'pull_request', action: 'something' } }

      it { is_expected.to be false }
    end

    context 'for an updated pull request from GitHub' do
      let(:payload) { { scm: 'github', event: 'pull_request', action: 'synchronize' } }

      it { is_expected.to be true }
    end

    context 'for an unsupported event from GitLab' do
      let(:payload) { { scm: 'gitlab', event: 'something', action: 'update' } }

      it { is_expected.to be false }
    end

    context 'for an unsupported action from GitLab' do
      let(:payload) { { scm: 'gitlab', event: 'Merge Request Hook', action: 'something' } }

      it { is_expected.to be false }
    end

    context 'for an updated merge request from GitLab' do
      let(:payload) { { scm: 'gitlab', event: 'Merge Request Hook', action: 'update' } }

      it { is_expected.to be true }
    end
  end

  describe '#closed_merged_pull_request?' do
    subject { described_class.new(payload: payload).closed_merged_pull_request? }

    context 'for an unsupported SCM' do
      let(:payload) { { scm: 'GitHoob', event: 'pull_request', action: 'closed' } }

      it { is_expected.to be false }
    end

    context 'for an unsupported event from GitHub' do
      let(:payload) { { scm: 'github', event: 'something', action: 'closed' } }

      it { is_expected.to be false }
    end

    context 'for an unsupported action from GitHub' do
      let(:payload) { { scm: 'github', event: 'pull_request', action: 'something' } }

      it { is_expected.to be false }
    end

    context 'for a closed/merged pull request from GitHub' do
      let(:payload) { { scm: 'github', event: 'pull_request', action: 'closed' } }

      it { is_expected.to be true }
    end

    context 'for an unsupported event from GitLab' do
      let(:payload) { { scm: 'gitlab', event: 'something', action: 'close' } }

      it { is_expected.to be false }
    end

    context 'for an unsupported action from GitLab' do
      let(:payload) { { scm: 'gitlab', event: 'Merge Request Hook', action: 'something' } }

      it { is_expected.to be false }
    end

    context 'for a closed merge request from GitLab' do
      let(:payload) { { scm: 'gitlab', event: 'Merge Request Hook', action: 'close' } }

      it { is_expected.to be true }
    end

    context 'for a merged merge request from GitLab' do
      let(:payload) { { scm: 'gitlab', event: 'Merge Request Hook', action: 'merge' } }

      it { is_expected.to be true }
    end
  end

  describe '#reopened_pull_request?' do
    subject { described_class.new(payload: payload).reopened_pull_request? }

    context 'for an unsupported SCM' do
      let(:payload) { { scm: 'GitHoob', event: 'pull_request', action: 'reopened' } }

      it { is_expected.to be false }
    end

    context 'for an unsupported event from GitHub' do
      let(:payload) { { scm: 'github', event: 'something', action: 'reopened' } }

      it { is_expected.to be false }
    end

    context 'for an unsupported action from GitHub' do
      let(:payload) { { scm: 'github', event: 'pull_request', action: 'something' } }

      it { is_expected.to be false }
    end

    context 'for a reopened pull request from GitHub' do
      let(:payload) { { scm: 'github', event: 'pull_request', action: 'reopened' } }

      it { is_expected.to be true }
    end

    context 'for an unsupported event from GitLab' do
      let(:payload) { { scm: 'gitlab', event: 'something', action: 'reopen' } }

      it { is_expected.to be false }
    end

    context 'for an unsupported action from GitLab' do
      let(:payload) { { scm: 'gitlab', event: 'Merge Request Hook', action: 'something' } }

      it { is_expected.to be false }
    end

    context 'for a reopened merge request from GitLab' do
      let(:payload) { { scm: 'gitlab', event: 'Merge Request Hook', action: 'reopen' } }

      it { is_expected.to be true }
    end
  end

  describe '#push_event?' do
    subject { described_class.new(payload: payload).push_event? }

    context 'for an unsupported SCM' do
      let(:payload) { { scm: 'GitHoob', event: 'push' } }

      it { is_expected.to be false }
    end

    context 'for an unsupported event from GitHub' do
      let(:payload) { { scm: 'github', event: 'something' } }

      it { is_expected.to be false }
    end

    context 'for an unsupported event from GitLab' do
      let(:payload) { { scm: 'gitlab', event: 'something' } }

      it { is_expected.to be false }
    end

    context 'for a push event from GitHub' do
      let(:payload) { { scm: 'github', event: 'push' } }

      it { is_expected.to be true }
    end

    context 'for a push event from GitLab' do
      let(:payload) { { scm: 'gitlab', event: 'Push Hook' } }

      it { is_expected.to be true }
    end
  end

  describe '#pull_request_event?' do
    subject { described_class.new(payload: payload).pull_request_event? }

    context 'for an unsupported SCM' do
      let(:payload) { { scm: 'GitHoob', event: 'pull_request' } }

      it { is_expected.to be false }
    end

    context 'for an unsupported event from GitHub' do
      let(:payload) { { scm: 'github', event: 'something' } }

      it { is_expected.to be false }
    end

    context 'for an unsupported event from GitLab' do
      let(:payload) { { scm: 'gitlab', event: 'something' } }

      it { is_expected.to be false }
    end

    context 'for a pull request event from GitHub' do
      let(:payload) { { scm: 'github', event: 'pull_request' } }

      it { is_expected.to be true }
    end

    context 'for a merge request event from GitLab' do
      let(:payload) { { scm: 'gitlab', event: 'Merge Request Hook' } }

      it { is_expected.to be true }
    end
  end
end
