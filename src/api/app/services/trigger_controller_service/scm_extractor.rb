module TriggerControllerService
  # NOTE: this class is coupled to GitHub pull requests events and GitLab merge requests events.
  class ScmExtractor
    ALLOWED_GITHUB_ACTIONS = ['opened', 'synchronize', 'closed'].freeze
    ALLOWED_GITLAB_ACTIONS = ['open', 'update', 'close', 'reopen', 'merge'].freeze

    def initialize(scm, event, payload)
      # TODO: What should we do when the user sends a wwwurlencoded payload? Raise an exception?
      @payload = payload.with_indifferent_access
      @scm = scm
      @event = event
    end

    def allowed_event_and_action?
      allowed_github_event_and_action? || allowed_gitlab_event_and_action?
    end

    # TODO: What happens when some of the keys are missing?
    def call
      case @scm
      when 'github'
        github_extractor_payload
      when 'gitlab'
        gitlab_extractor_payload
      end
    end

    private

    def allowed_github_event_and_action?
      @event == 'pull_request' && @payload['action'].in?(ALLOWED_GITHUB_ACTIONS)
    end

    def allowed_gitlab_event_and_action?
      @event == 'Merge Request Hook' && @payload['object_attributes']['action'].in?(ALLOWED_GITLAB_ACTIONS)
    end

    def github_extractor_payload
      {
        scm: 'github',
        repo_url: @payload.dig('pull_request', 'head', 'repo', 'html_url'),
        commit_sha: @payload.dig('pull_request', 'head', 'sha'),
        pr_number: @payload['number'],
        source_branch: @payload.dig('pull_request', 'head', 'ref'),
        target_branch: @payload.dig('pull_request', 'base', 'ref'),
        action: @payload['action'], # TODO: Names may differ, maybe we need to find our own naming (defer to service?)
        repository_full_name: @payload.dig('pull_request', 'head', 'repo', 'full_name'),
        event: @event
      }.with_indifferent_access
    end

    def gitlab_extractor_payload
      {
        scm: 'gitlab',
        object_kind: @payload['object_kind'],
        http_url: @payload.dig('project', 'http_url'),
        commit_sha: @payload.dig('object_attributes', 'last_commit', 'id'),
        pr_number: @payload.dig('object_attributes', 'iid'),
        source_branch: @payload.dig('object_attributes', 'source_branch'),
        target_branch: @payload.dig('object_attributes', 'target_branch'),
        action: @payload.dig('object_attributes', 'action'), # TODO: Names may differ, maybe we need to find our own naming (defer to service?)
        project_id: @payload.dig('project', 'id'),
        path_with_namespace: @payload.dig('project', 'path_with_namespace'),
        event: @event
      }.with_indifferent_access
    end
  end
end
