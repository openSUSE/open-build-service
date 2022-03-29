require 'rails_helper'
require Rails.root.join('db/data/20220329152245_backfill_workflow_run_request_json_payload.rb')

RSpec.describe BackfillWorkflowRunRequestJsonPayload, type: :migration do
  describe 'up' do
    subject { BackfillWorkflowRunRequestJsonPayload.new.up }

    before do
      create(:workflow_run)
    end

    it 'fills request_json_payload field with the content of request_payload field' do
      subject
      workflow_run = WorkflowRun.last
      expect(workflow_run.request_json_payload).to eq(workflow_run.request_payload)
    end
  end
end
