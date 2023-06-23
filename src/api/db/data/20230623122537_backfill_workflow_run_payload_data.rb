# frozen_string_literal: true

class BackfillWorkflowRunPayloadData < ActiveRecord::Migration[7.0]
  include ScmWebhookPayloadDataExtractor

  def up
    WorkflowRun.where(hook_action: nil).in_batches do |workflow_runs|
      workflow_runs.each do |workflow_run|
        @workflow_run = workflow_run
        workflow_run.hook_action = extract_hook_action
        workflow_run.repository_name = extract_repository_name
        workflow_run.repository_owner = extract_repository_owner
        workflow_run.event_source_name = extract_event_source_name
        workflow_run.save!
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  def payload
    @workflow_run.payload.presence || {}
  end

  def hook_event
    @workflow_run.hook_event
  end
end
