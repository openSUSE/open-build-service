module TriggerControllerService
  # NOTE: this class is coupled to GitHub pull requests events and GitLab merge requests events.
  class ScmExtractor
    ALLOWED_GITHUB_ACTIONS = ['opened', 'synchronize', 'closed'].freeze
    ALLOWED_GITLAB_ACTIONS = ['open', 'update', 'close', 'reopen', 'merge'].freeze

    def initialize(scm, event, payload)
      # TODO: What should we do when the user sends a wwwurlencoded payload? Raise an exception?
      @payload = payload
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
        {
          scm: 'github',
          repo_url: @payload['pull_request']['head']['repo']['html_url'],
          commit_sha: @payload['pull_request']['head']['sha'],
          pr_number: @payload['number'],
          branch: @payload['pull_request']['head']['ref'],
          action: @payload['action'], # TODO: Names may differ, maybe we need to find our own naming (defer to service?)
          repository_owner: @payload['pull_request']['head']['repo']['owner']['login'],
          repository_name: @payload['pull_request']['head']['repo']['name']
        }.with_independent_access
      when 'gitlab'
        {
          scm: 'gitlab',
          repo_url: @payload['project']['web_url'],
          commit_sha: @payload['object_attributes']['last_commit']['id'],
          pr_number: @payload['object_attributes']['iid'],
          branch: @payload['object_attributes']['source_branch'],
          action: @payload['object_attributes']['action'], # TODO: Names may differ, maybe we need to find our own naming (defer to service?)
          project_id: @payload['project']['id'],
          path_with_namespace: @payload['project']['path_with_namespace']
        }.with_independent_access
      end
    end

    private

    def allowed_github_event_and_action?
      @event == 'pull_request' && @payload['action'].in?(ALLOWED_GITHUB_ACTIONS)
    end

    def allowed_gitlab_event_and_action?
      @event == 'Merge Request Hook' && @payload['object_attributes']['action'].in?(ALLOWED_GITLAB_ACTIONS)
    end
  end
end
