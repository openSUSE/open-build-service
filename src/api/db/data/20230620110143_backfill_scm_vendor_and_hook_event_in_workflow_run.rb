# frozen_string_literal: true

class BackfillScmVendorAndHookEventInWorkflowRun < ActiveRecord::Migration[7.0]
  def up
    WorkflowRun.where(scm_vendor: nil, hook_event: nil).each do |workflow_run|
      headers = parse_request_headers(workflow_run)
      workflow_run.update(scm_vendor: scm_vendor(headers),
                          hook_event: hook_event(headers))
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  def scm_vendor(headers)
    if headers['HTTP_X_GITEA_EVENT']
      'gitea'
    elsif headers['HTTP_X_GITHUB_EVENT']
      'github'
    elsif headers['HTTP_X_GITLAB_EVENT']
      'gitlab'
    end
  end

  def hook_event(headers)
    headers['HTTP_X_GITHUB_EVENT'] ||
      headers['HTTP_X_GITLAB_EVENT'] || nil
  end

  def parse_request_headers(workflow_run)
    workflow_run.request_headers.split("\n").each_with_object({}) do |h, headers|
      k, v = h.split(':')
      headers[k] = v.strip
    end
  end
end
