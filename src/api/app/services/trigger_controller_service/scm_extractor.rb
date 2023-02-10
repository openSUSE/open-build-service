module TriggerControllerService
  class SCMExtractor
    SCM_EXTRACTORS = {
      'github' => {
        'pull_request' => GithubPayload::PullRequest,
        'push' => GithubPayload::Push
      },
      'gitlab' => {
        'Merge Request Hook' => GitlabPayload::MergeRequest,
        'Push Hook' => GitlabPayload::Push,
        'Tag Push Hook' => GitlabPayload::TagPush
      },
      'gitea' => {
        'pull_request' => GiteaPayload::PullRequest,
        'push' => GiteaPayload::Push
      }
    }.freeze

    def initialize(scm, event, webhook_payload)
      # TODO: What should we do when the user sends a wwwurlencoded payload? Raise an exception?
      @webhook_payload = webhook_payload.deep_symbolize_keys
      @scm = scm
      @event = event
    end

    # TODO: What happens when some of the keys are missing?
    def call
      extractor = SCM_EXTRACTORS.dig(@scm, @event)
      return unless extractor

      SCMWebhook.new(payload: extractor.new(@webhook_payload).payload)
    end
  end
end
