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
        SCMWebhook.new(payload: gitea_extractor_payload)
      end
    end

    private

    def gitea_extractor_payload
      http_url = @payload.dig(:repository, :clone_url)

      payload = {
        scm: 'gitea',
        event: @event,
        api_endpoint: gitea_api_endpoint(http_url),
        http_url: http_url
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
      when 'push' # GitHub doesn't have different push events for commits and tags
        gitea_payload_push(payload)
      end
      payload
    end

    def gitea_api_endpoint(http_url)
      url = URI.parse(http_url)

      "#{url.scheme}://#{url.host}"
    end

    def gitea_payload_push(payload)
      payload_ref = @payload.fetch(:ref, '')
      payload.merge!({
                       # We need this for Workflow::Step#branch_request_content_github
                       source_repository_full_name: @payload.dig(:repository, :full_name),
                       # We need this for SCMStatusReporter#call
                       target_repository_full_name: @payload.dig(:repository, :full_name),
                       ref: payload_ref,
                       # We need this for Workflow::Step#branch_request_content_{github,gitlab}
                       commit_sha: @payload[:after],
                       # We need this for Workflows::YAMLDownloader#download_url
                       # when the push event is for commits, we get the branch name from ref.
                       target_branch: payload_ref.sub('refs/heads/', '')
                     })

      return unless payload_ref.start_with?('refs/tags/')

      # We need this for Workflow::Step#target_package_name
      # 'target_branch' will contain a commit SHA
      payload.merge!({ tag_name: payload_ref.sub('refs/tags/', ''),
                       target_branch: @payload.dig(:head_commit, :id),
                       commit_sha: @payload.dig(:head_commit, :id) })
    end
  end
end
