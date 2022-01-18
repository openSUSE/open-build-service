class WorkflowRunRowComponent < ApplicationComponent
  attr_reader :workflow_run, :status

  def initialize(workflow_run:)
    super

    @workflow_run = workflow_run
    @status = workflow_run.status
  end

  def hook_action
    return payload['action'] if
      hook_event == 'pull_request' && ScmWebhookEventValidator::ALLOWED_PULL_REQUEST_ACTIONS.include?(payload['action'])
  end

  def hook_event
    parsed_request_headers['HTTP_X_GITHUB_EVENT']
  end

  def repository_name
    payload.dig('repository', 'full_name')
  end

  def repository_url
    payload.dig('repository', 'html_url')
  end

  def hook_source_name
    case hook_event
    when 'pull_request'
      payload.dig('pull_request', 'number')
    when 'push'
      payload.dig('head_commit', 'id')
    else
      payload.dig('repository', 'full_name')
    end
  end

  def formatted_hook_source_name
    case hook_event
    when 'pull_request'
      "##{hook_source_name}"
    else
      hook_source_name
    end
  end

  def hook_source_url
    case hook_event
    when 'pull_request'
      payload.dig('pull_request', 'url')
    when 'push'
      payload.dig('head_commit', 'url')
    else
      payload.dig('repository', 'html_url')
    end
  end

  def status_title
    case status
    when 'running'
      'Status: running'
    when 'success'
      'Status: success'
    else
      'Status: failed'
    end
  end

  def status_icon
    classes = case status
              when 'running'
                ['fas', 'fa-running']
              when 'success'
                ['fas', 'fa-check', 'text-primary']
              else
                ['fas', 'fa-exclamation-triangle', 'text-danger']
              end
    classes.join(' ')
  end

  private

  def parsed_request_headers
    workflow_run.request_headers.split("\n").each_with_object({}) do |h, headers|
      k, v = h.split(':')
      headers[k] = v.strip
    end
  end

  def payload
    @payload ||= JSON.parse(workflow_run.request_payload)
  rescue JSON::ParserError
    {}
  end
end
