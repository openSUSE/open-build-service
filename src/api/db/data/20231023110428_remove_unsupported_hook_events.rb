# frozen_string_literal: true

class RemoveUnsupportedHookEvents < ActiveRecord::Migration[7.0]
  def up
    WorkflowRun.where.not(hook_event: [*SCMWebhookEventValidator::ALLOWED_GITHUB_AND_GITEA_EVENTS, *SCMWebhookEventValidator::ALLOWED_GITLAB_EVENTS]).destroy_all
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
