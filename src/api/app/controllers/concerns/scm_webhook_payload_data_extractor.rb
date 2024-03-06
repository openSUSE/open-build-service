module ScmWebhookPayloadDataExtractor
  extend ActiveSupport::Concern

  SOURCE_NAME_PAYLOAD_MAPPING = {
    'pull_request' => %w[pull_request number],
    'Merge Request Hook' => %w[object_attributes iid],
    'push' => %w[head_commit id],
    'Push Hook' => ['commits', 0, 'id']
  }.freeze

  def payload
    request_body = request.body.read
    raise Trigger::Errors::BadSCMPayload if request_body.blank?

    begin
      JSON.parse(request_body)
    rescue JSON::ParserError
      raise Trigger::Errors::BadSCMPayload
    end
  end

  def extract_hook_action
    return payload['action'] if pull_request_with_allowed_action

    payload.dig('object_attributes', 'action') if merge_request_with_allowed_action
  end

  def extract_repository_name
    payload.dig('repository', 'name') || # For GitHub and Gitea
      payload.dig('project', 'path_with_namespace')&.split('/')&.last # For GitLab
  end

  def extract_repository_owner
    payload.dig('repository', 'owner', 'login') || # For GitHub and Gitea
      payload.dig('project', 'path_with_namespace')&.split('/')&.first # For GitLab
  end

  def extract_event_source_name
    path = SOURCE_NAME_PAYLOAD_MAPPING[hook_event]
    payload.dig(*path) if path
  end

  def pull_request_with_allowed_action
    hook_event == 'pull_request' &&
      SCMWebhook::ALLOWED_PULL_REQUEST_ACTIONS.include?(payload['action'])
  end

  def merge_request_with_allowed_action
    hook_event == 'Merge Request Hook' &&
      SCMWebhook::ALLOWED_MERGE_REQUEST_ACTIONS.include?(payload.dig('object_attributes', 'action'))
  end
end
