module TriggerControllerService
  # NOTE: this class is coupled to GitHub pull requests events and GitLab merge requests events.
  class SCMExtractor
    def initialize(scm, event, payload)
      # TODO: What should we do when the user sends a wwwurlencoded payload? Raise an exception?
      @payload = payload.deep_symbolize_keys
      @scm = scm
      @event = event
    end

    # TODO: What happens when some of the keys are missing?
    def call
      case @scm
      when 'github'
        SCMWebhook.new(payload: GithubPayloadExtractor.new(@event, @payload).payload)
      when 'gitlab'
        SCMWebhook.new(payload: GitlabPayloadExtractor.new(@event, @payload).payload)
      when 'gitea'
        SCMWebhook.new(payload: GiteaPayloadExtractor.new(@event, @payload).payload)
      end
    end
  end
end
