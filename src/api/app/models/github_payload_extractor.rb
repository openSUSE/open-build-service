class GithubPayloadExtractor < ScmPayloadExtractor
  attr_reader :event, :webhook_payload

  def initialize(event, webhook_payload)
    super()
    @event = event
    @webhook_payload = webhook_payload
  end

  def payload
    payload = {
      scm: 'github',
      event: event,
      api_endpoint: github_api_endpoint
    }

    case event
    when 'pull_request'
      return Github::PullRequest.new(event, webhook_payload).payload
    when 'push' # GitHub doesn't have different push events for commits and tags
      github_payload_push(payload)
    end

    payload
  end

  private

  def github_api_endpoint
    sender_url = webhook_payload.dig(:sender, :url)
    return unless sender_url

    host = URI.parse(sender_url).host
    if host.start_with?('api.github.com')
      "https://#{host}"
    else
      "https://#{host}/api/v3/"
    end
  end

  def github_payload_push(payload)
    payload_ref = @webhook_payload.fetch(:ref, '')
    payload.merge!({
                     # We need this for Workflow::Step#branch_request_content_github
                     source_repository_full_name: @webhook_payload.dig(:repository, :full_name),
                     # We need this for SCMStatusReporter#call
                     target_repository_full_name: @webhook_payload.dig(:repository, :full_name),
                     ref: payload_ref,
                     # We need this for Workflow::Step#branch_request_content_{github,gitlab}
                     commit_sha: @webhook_payload[:after],
                     # We need this for Workflows::YAMLDownloader#download_url
                     # when the push event is for commits, we get the branch name from ref.
                     target_branch: payload_ref.sub('refs/heads/', '')
                   })

    return unless payload_ref.start_with?('refs/tags/')

    # We need this for Workflow::Step#target_package_name
    # 'target_branch' will contain a commit SHA
    payload.merge!({ tag_name: payload_ref.sub('refs/tags/', ''),
                     target_branch: @webhook_payload.dig(:head_commit, :id),
                     commit_sha: @webhook_payload.dig(:head_commit, :id) })
  end
end
