module TriggerControllerService
  # NOTE: this class is coupled to GitHub pull requests events and GitLab merge requests events.
  class ScmExtractor
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
        ScmWebhook.new(payload: github_extractor_payload)
      when 'gitlab'
        ScmWebhook.new(payload: gitlab_extractor_payload)
      end
    end

    private

    def github_extractor_payload
      payload = {
        scm: 'github',
        event: @event,
        api_endpoint: github_api_endpoint
      }

      case @event
      when 'pull_request'
        payload.merge!({ commit_sha: @payload.dig(:pull_request, :head, :sha),
                         pr_number: @payload[:number],
                         source_branch: @payload.dig(:pull_request, :head, :ref),
                         target_branch: @payload.dig(:pull_request, :base, :ref),
                         action: @payload[:action],
                         source_repository_full_name: @payload.dig(:pull_request, :head, :repo, :full_name),
                         target_repository_full_name: @payload.dig(:pull_request, :base, :repo, :full_name) })
      when 'push'
        payload.merge!({ commit_sha: @payload[:after],
                         # We need this for Workflows::YAMLDownloader#download_url
                         target_branch: @payload[:ref].sub('refs/heads/', ''),
                         # We need this for Workflow::Step#branch_request_content_github
                         source_repository_full_name: @payload.dig(:repository, :full_name),
                         # We need this for SCMStatusReporter#call
                         target_repository_full_name: @payload.dig(:repository, :full_name),
                         ref: @payload[:ref] })
      end
      payload
    end

    def gitlab_extractor_payload
      http_url = @payload.dig(:project, :http_url)

      payload = {
        scm: 'gitlab',
        object_kind: @payload[:object_kind],
        http_url: http_url,
        event: @event,
        api_endpoint: gitlab_api_endpoint(http_url)
      }

      case @event
      when 'Merge Request Hook'
        payload.merge!({ commit_sha: @payload.dig(:object_attributes, :last_commit, :id),
                         pr_number: @payload.dig(:object_attributes, :iid),
                         source_branch: @payload.dig(:object_attributes, :source_branch),
                         target_branch: @payload.dig(:object_attributes, :target_branch),
                         action: @payload.dig(:object_attributes, :action),
                         project_id: @payload.dig(:object_attributes, :source_project_id),
                         path_with_namespace: @payload.dig(:project, :path_with_namespace) })
      when 'Push Hook'
        payload.merge!({ commit_sha: @payload[:after],
                         # We need this for Workflows::YAMLDownloader#download_url
                         target_branch: @payload[:ref].sub('refs/heads/', ''),
                         # We need this for Workflows::YAMLDownloader#download_url
                         path_with_namespace: @payload.dig(:project, :path_with_namespace),
                         project_id: @payload[:project_id],
                         ref: @payload[:ref] })
      end
      payload
    end

    def github_api_endpoint
      sender_url = @payload.dig(:sender, :url)
      return unless sender_url

      host = URI.parse(sender_url).host
      if host.start_with?('api.github.com')
        "https://#{host}"
      else
        "https://#{host}/api/v3/"
      end
    end

    def gitlab_api_endpoint(http_url)
      return unless http_url

      uri = URI.parse(http_url)
      "#{uri.scheme}://#{uri.host}"
    end
  end
end
