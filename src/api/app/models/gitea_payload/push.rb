# This class is used in TriggerControllerServicve::ScmExtractor to handle push events coming from Gitea.
# It's basically the same than the pushes coming from Github but with some customizations on top.
class GiteaPayload::Push < GiteaPayload
  def payload
    payload_ref = webhook_payload.fetch(:ref, '')
    payload = default_payload.merge(
      event: 'push',
      # We need this for Workflow::Step#branch_request_content_github
      source_repository_full_name: webhook_payload.dig(:repository, :full_name),
      # We need this for SCMStatusReporter#call
      target_repository_full_name: webhook_payload.dig(:repository, :full_name),
      ref: payload_ref,
      # We need this for Workflow::Step#branch_request_content_{github,gitlab}
      commit_sha: webhook_payload[:after],
      # We need this for Workflows::YAMLDownloader#download_url
      # when the push event is for commits, we get the branch name from ref.
      target_branch: payload_ref.sub('refs/heads/', '')
    )

    return payload unless payload_ref.start_with?('refs/tags/')

    # We need this for Workflow::Step#target_package_name
    # 'target_branch' will contain a commit SHA
    payload.merge(tag_name: payload_ref.sub('refs/tags/', ''),
                  target_branch: webhook_payload.dig(:head_commit, :id),
                  commit_sha: webhook_payload.dig(:head_commit, :id))
  end
end
