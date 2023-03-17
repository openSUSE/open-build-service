module TriggerControllerService
  class SCMExtractor
    attr_reader :extractor

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
      @scm = scm
      @event = event
      @webhook_payload = webhook_payload.deep_symbolize_keys
      @extractor = SCM_EXTRACTORS.dig(@scm, @event)
    end

    # TODO: What happens when some of the keys are missing?
    def call
      return unless extractor

      SCMWebhook.new(payload: extractor.new(@webhook_payload).payload)
    end

    def valid?
      @scm.present? && @extractor.present?
    end

    def error_message
      return 'Only GitHub, GitLab and Gitea are supported. Could not find the required HTTP request headers X-GitHub-Event, X-Gitlab-Event or X-Gitea-Event.' if @scm.nil?

      'This SCM event is not supported' if @extractor.nil?
    end
  end
end
