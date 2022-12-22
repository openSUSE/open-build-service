class GitlabPayloadExtractor
  attr_reader :event, :webhook_payload

  def initialize(event, webhook_payload)
    super()
    @event = event
    @webhook_payload = webhook_payload
  end

  def payload
    http_url = webhook_payload.dig(:project, :http_url)

    payload = {
      scm: 'gitlab',
      object_kind: webhook_payload[:object_kind],
      http_url: http_url,
      event: event,
      api_endpoint: gitlab_api_endpoint(http_url)
    }

    case event
    when 'Merge Request Hook'
      return GitlabPayload::MergeRequest.new(event, webhook_payload).payload
    when 'Push Hook'
      payload.merge!({ commit_sha: webhook_payload[:after],
                       # We need this for Workflows::YAMLDownloader#download_url
                       target_branch: webhook_payload[:ref].sub('refs/heads/', ''),
                       # We need this for Workflows::YAMLDownloader#download_url
                       path_with_namespace: webhook_payload.dig(:project, :path_with_namespace),
                       # We need this for SCMStatusReporter#call
                       project_id: webhook_payload[:project_id],
                       # We need this for SCMWebhookEventValidator#valid_push_event
                       ref: webhook_payload[:ref] })
    when 'Tag Push Hook'
      gitlab_payload_tag(payload)
    end
    payload
  end

  private

  def gitlab_api_endpoint(http_url)
    return unless http_url

    uri = URI.parse(http_url)
    "#{uri.scheme}://#{uri.host}"
  end

  def gitlab_payload_tag(payload)
    payload.merge!({ # We need this for Workflow::Step#target_package_name
                     tag_name: webhook_payload[:ref].sub('refs/tags/', ''),
                     # We need this for Workflows::YAMLDownloader#download_url
                     # This will contain a commit SHA
                     target_branch: webhook_payload[:after],
                     # We need this for Workflows::YAMLDownloader#download_url
                     path_with_namespace: webhook_payload.dig(:project, :path_with_namespace),
                     # We need this for SCMWebhookEventValidator#valid_push_event
                     ref: webhook_payload[:ref],
                     # We need this for Workflow::Step#branch_request_content_{github,gitlab}
                     commit_sha: webhook_payload[:after]
                   })
  end
end
