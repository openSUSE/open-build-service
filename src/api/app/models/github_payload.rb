# This class is used as a common foundation for the pull request and push events coming from Github.
class GithubPayload < ScmPayload
  def default_payload
    {
      scm: 'github',
      api_endpoint: api_endpoint
    }
  end

  private

  def api_endpoint
    sender_url = webhook_payload.dig(:sender, :url)
    return unless sender_url

    host = URI.parse(sender_url).host
    if host.start_with?('api.github.com')
      "https://#{host}"
    else
      "https://#{host}/api/v3/"
    end
  end
end
