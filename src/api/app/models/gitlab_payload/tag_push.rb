# This class is used in TriggerControllerService::ScmExtractor to handle tag push events coming from Gitlab.
class GitlabPayload::TagPush < GitlabPayload
  def payload
    default_payload.merge( # We need this for Workflow::Step#target_package_name
      event: 'Tag Push Hook',
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
    )
  end
end
