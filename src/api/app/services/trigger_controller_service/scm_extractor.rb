module TriggerControllerService
  # NOTE: this class is coupled to GitHub pull requests events and GitLab merge requests events.
  class SCMExtractor
    SCM_EXTRACTORS = {
      'github' => GithubPayloadExtractor,
      'gitlab' => GitlabPayloadExtractor,
      'gitea' => GiteaPayloadExtractor
    }.freeze

    def initialize(scm, event, payload)
      # TODO: What should we do when the user sends a wwwurlencoded payload? Raise an exception?
      @payload = payload.deep_symbolize_keys
      @scm = scm
      @event = event
    end

    # TODO: What happens when some of the keys are missing?
    def call
      extractor = SCM_EXTRACTORS[@scm]
      return unless extractor

      SCMWebhook.new(payload: extractor.new(@event, @payload).payload)
    end
  end
end
