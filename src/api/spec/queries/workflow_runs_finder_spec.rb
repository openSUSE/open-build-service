require 'rails_helper'

RSpec.describe WorkflowRunsFinder do
  let(:workflow_token) { create(:workflow_token) }

  before do
    ScmWebhookEventValidator::ALLOWED_GITHUB_EVENTS.each do |event|
      create(:workflow_run, token: workflow_token, status: 'running', request_headers: "HTTP_X_GITHUB_EVENT: #{event}\n")
    end

    ScmWebhookEventValidator::ALLOWED_GITLAB_EVENTS.each do |event|
      create(:workflow_run, token: workflow_token, status: 'running', request_headers: "HTTP_X_GITLAB_EVENT: #{event}\n")
    end

    ['success', 'running', 'fail'].each do |status|
      create(:workflow_run, token: workflow_token, status: status, request_headers: "HTTP_X_GITHUB_EVENT: pull_request\n")
    end
  end

  subject { described_class.new }

  describe '#all' do
    it 'returns all workflow runs' do
      expect(subject.all.count).to eq(8)
    end
  end

  describe '#group_by_event_type' do
    it 'returns a hash with the amount of workflow runs grouped by event' do
      expect(subject.group_by_event_type).to include({ 'pull_request' => 4, 'push' => 1, 'Merge Request Hook' => 1, 'Push Hook' => 1, 'Tag Push Hook' => 1 })
    end
  end

  describe '#succeeded' do
    it 'returns all workflow runs with status success' do
      expect(subject.succeeded.count).to eq(1)
    end
  end

  describe '#running' do
    it 'returns all workflow runs with status running' do
      expect(subject.running.count).to eq(6)
    end
  end

  describe '#failed' do
    it 'returns all workflow runs with status fail' do
      expect(subject.failed.count).to eq(1)
    end
  end
end
