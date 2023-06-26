# frozen_string_literal: true

class BackfillWorkflowRunPayloadData < ActiveRecord::Migration[7.0]
  include ScmWebhookHeadersDataExtractor

  def up
    WorkflowRun.where.not(request_headers: '').in_batches do |workflow_runs|
      workflow_runs.each do |workflow_run|
        @workflow_run = workflow_run
        workflow_run.event_uuid = extract_event_uuid
        workflow_run.webhook_id = extract_webhook_id
        workflow_run.save!
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  def request
    @workflow_run.request_headers
  end
end
