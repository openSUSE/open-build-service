# This class is used as a common foundation for the merge request, push and tag push events coming from Gitlab.
class GitlabPayload < ScmPayload
  attr_reader :http_url

  def initialize(webhook_payload)
    super(webhook_payload)
    @http_url = webhook_payload.dig(:project, :http_url)
  end

  def default_payload
    {
      scm: 'gitlab',
      object_kind: webhook_payload[:object_kind],
      http_url: http_url,
      api_endpoint: api_endpoint
    }
  end

  private

  def api_endpoint
    return unless http_url

    uri = URI.parse(http_url)
    "#{uri.scheme}://#{uri.host}"
  end
end
