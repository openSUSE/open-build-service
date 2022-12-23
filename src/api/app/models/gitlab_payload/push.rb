# This class is used in TriggerControllerService::ScmExtractor to handle push events coming from Gitlab.
class GitlabPayload::Push < GitlabPayload
  def payload
    default_payload.merge(event: 'Push Hook',
                          commit_sha: webhook_payload[:after],
                          # We need this for Workflows::YAMLDownloader#download_url
                          target_branch: webhook_payload[:ref].sub('refs/heads/', ''),
                          # We need this for Workflows::YAMLDownloader#download_url
                          path_with_namespace: webhook_payload.dig(:project, :path_with_namespace),
                          # We need this for SCMStatusReporter#call
                          project_id: webhook_payload[:project_id],
                          # We need this for SCMWebhookEventValidator#valid_push_event
                          ref: webhook_payload[:ref])
  end
end
