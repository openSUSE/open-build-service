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

  describe '#group_by_generic_event_type' do
    it 'returns a hash with the amount of workflow runs grouped by event' do
      expect(subject.group_by_generic_event_type).to include({ 'pull_request' => 5, 'push' => 3 })
    end
  end

  describe '#with_generic_event_type' do
    it 'returns workflows for pull_request generic event' do
      expect(subject.with_generic_event_type('pull_request').count).to eq(5)
    end

    it 'returns workflows for push generic event' do
      expect(subject.with_generic_event_type('push').count).to eq(3)
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
