require 'rails_helper'

RSpec.describe SCMWebhook do
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

    context 'for an unsupported event from Gitea' do
      let(:payload) { { scm: 'gitea', event: 'something', action: 'opened' } }

      it { is_expected.to be false }
    end

    context 'for an unsupported action from Gitea' do
      let(:payload) { { scm: 'gitea', event: 'pull_request', action: 'something' } }

      it { is_expected.to be false }
    end

    context 'for a new pull request from Gitea' do
      let(:payload) { { scm: 'gitea', event: 'pull_request', action: 'opened' } }

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

    context 'for an unsupported event from Gitea' do
      let(:payload) { { scm: 'gitea', event: 'something', action: 'synchronized' } }

      it { is_expected.to be false }
    end

    context 'for an unsupported action from Gitea' do
      let(:payload) { { scm: 'gitea', event: 'pull_request', action: 'something' } }

      it { is_expected.to be false }
    end

    context 'for an updated pull request from Gitea' do
      let(:payload) { { scm: 'gitea', event: 'pull_request', action: 'synchronized' } }

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

    context 'for an unsupported event from Gitea' do
      let(:payload) { { scm: 'gitea', event: 'something', action: 'closed' } }

      it { is_expected.to be false }
    end

    context 'for an unsupported action from Gitea' do
      let(:payload) { { scm: 'gitea', event: 'pull_request', action: 'something' } }

      it { is_expected.to be false }
    end

    context 'for a closed/merged pull request from Gitea' do
      let(:payload) { { scm: 'gitea', event: 'pull_request', action: 'closed' } }

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

    context 'for an unsupported event from Gitea' do
      let(:payload) { { scm: 'gitea', event: 'something', action: 'reopened' } }

      it { is_expected.to be false }
    end

    context 'for an unsupported action from Gitea' do
      let(:payload) { { scm: 'gitea', event: 'pull_request', action: 'something' } }

      it { is_expected.to be false }
    end

    context 'for a reopened pull request from Gitea' do
      let(:payload) { { scm: 'gitea', event: 'pull_request', action: 'reopened' } }

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

    context 'for an unsupported event from Gitea' do
      let(:payload) { { scm: 'gitea', event: 'something' } }

      it { is_expected.to be false }
    end

    context 'with a push event from GitHub for a tag' do
      let(:payload) { { scm: 'github', event: 'push', ref: 'refs/tags/release_abc' } }

      it { is_expected.to be false }
    end

    context 'with a push event from GitLab for a tag' do
      let(:payload) { { scm: 'gitlab', event: 'Tag Push Hook' } }

      it { is_expected.to be false }
    end

    context 'with a push event from Gitea for a tag' do
      let(:payload) { { scm: 'gitea', event: 'push', ref: 'refs/tags/release_abc' } }

      it { is_expected.to be false }
    end

    context 'with a push event from GitHub for a commit' do
      let(:payload) { { scm: 'github', event: 'push', ref: 'refs/heads/branch_123' } }

      it { is_expected.to be true }
    end

    context 'with a push event from GitLab for a commit' do
      let(:payload) { { scm: 'gitlab', event: 'Push Hook' } }

      it { is_expected.to be true }
    end

    context 'with a push event from Gitea for a commit' do
      let(:payload) { { scm: 'gitea', event: 'push', ref: 'refs/heads/branch_123' } }

      it { is_expected.to be true }
    end
  end

  describe '#tag_push_event?' do
    subject { described_class.new(payload: payload).tag_push_event? }

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

    context 'for an unsupported event from Gitea' do
      let(:payload) { { scm: 'gitea', event: 'something' } }

      it { is_expected.to be false }
    end

    context 'with a push event from GitHub for a commit' do
      let(:payload) { { scm: 'github', event: 'push', ref: 'refs/heads/branch_123' } }

      it { is_expected.to be false }
    end

    context 'with a push event from GitLab for a commit' do
      let(:payload) { { scm: 'gitlab', event: 'Push Hook' } }

      it { is_expected.to be false }
    end

    context 'with a push event from Gitea for a commit' do
      let(:payload) { { scm: 'gitea', event: 'push', ref: 'refs/heads/branch_123' } }

      it { is_expected.to be false }
    end

    context 'with a push event from GitHub for a tag' do
      let(:payload) { { scm: 'github', event: 'push', ref: 'refs/tags/release_abc' } }

      it { is_expected.to be true }
    end

    context 'with a push event from GitLab for a tag' do
      let(:payload) { { scm: 'gitlab', event: 'Tag Push Hook' } }

      it { is_expected.to be true }
    end

    context 'with a push event from Gitea for a tag' do
      let(:payload) { { scm: 'gitea', event: 'push', ref: 'refs/tags/release_abc' } }

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

    context 'for an unsupported event from Gitea' do
      let(:payload) { { scm: 'gitea', event: 'something' } }

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

    context 'for a pull request event from Gitea' do
      let(:payload) { { scm: 'gitea', event: 'pull_request' } }

      it { is_expected.to be true }
    end
  end

  describe '#ignored_push_event?' do
    subject { described_class.new(payload: payload).ignored_push_event? }

    context 'with a push event from GitHub for a deleted commit reference' do
      let(:payload) { { scm: 'github', event: 'push', ref: 'refs/heads/branch_123', deleted: true } }

      it { is_expected.to be true }
    end

    context 'with a push event from GitHub without a deleted commit reference' do
      let(:payload) { { scm: 'github', event: 'push', ref: 'refs/heads/branch_123', deleted: false } }

      it { is_expected.to be false }
    end

    context 'with a Push Hook event from Gitlab for a deleted commit reference' do
      let(:payload) { { scm: 'gitlab', event: 'Push Hook', ref: 'refs/heads/branch_123', commit_sha: '0000000000000000000000000000000000000000' } }

      it { is_expected.to be true }
    end

    context 'with a Push Hook event from Gitlab without a deleted commit reference' do
      let(:payload) { { scm: 'gitlab', event: 'Push Hook', ref: 'refs/heads/branch_123', commit_sha: 'd8964263418b3946a6d540a50d09c89c6e13e82d' } }

      it { is_expected.to be false }
    end
  end
end
