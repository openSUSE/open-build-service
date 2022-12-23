# This class is used in TriggerControllerService::ScmExtractor to handle merge request events coming from Gitlab.
class GitlabPayload::MergeRequest < GitlabPayload
  def payload
    default_payload.merge(event: 'Merge Request Hook',
                          commit_sha: webhook_payload.dig(:object_attributes, :last_commit, :id),
                          pr_number: webhook_payload.dig(:object_attributes, :iid),
                          source_branch: webhook_payload.dig(:object_attributes, :source_branch),
                          target_branch: webhook_payload.dig(:object_attributes, :target_branch),
                          action: webhook_payload.dig(:object_attributes, :action),
                          project_id: webhook_payload.dig(:object_attributes, :source_project_id),
                          path_with_namespace: webhook_payload.dig(:project, :path_with_namespace))
  end
end
