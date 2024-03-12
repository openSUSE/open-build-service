module TriggerControllerService
  class TokenExtractor
    def initialize(http_request)
      @http_request = http_request
      @token_id = http_request.params[:id]
      @body = @http_request.body.read
    end

    def call
      if @token_id && signature
        extract_token_from_request_signature
      else
        extract_auth_token_from_headers
      end
    end

    private

    def extract_token_string_from_authorization_header
      http_auth = @http_request.env['HTTP_AUTHORIZATION']

      http_auth.slice(6..-1) if http_auth.present? && http_auth[0..4] == 'Token'
    end

    def extract_auth_token_from_headers
      auth_token = @http_request.env['HTTP_X_GITLAB_TOKEN'] ||
                   extract_token_string_from_authorization_header

      return unless auth_token

      Token.find_by_string!(auth_token) if auth_token.match?(%r{^[A-Za-z0-9+/]+$})
    end

    def extract_token_from_request_signature
      token = Token.find_by(id: @token_id)
      token if token && valid_signature?(token.string)
    end

    def valid_signature?(token_string)
      return false unless signature

      ActiveSupport::SecurityUtils.secure_compare(signature_of(token_string), signature)
    end

    def signature_of(token_string)
      "sha256=#{OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), token_string, @body)}"
    end

    # To trigger the webhook, the sender needs to
    # generate a signature with a secret token.
    # The signature needs to be generated over the
    # payload of the HTTP request and stored
    # in a HTTP header.
    # GitHub: HTTP_X_HUB_SIGNATURE_256
    # https://developer.github.com/webhooks/securing/
    # Pagure: HTTP_X-Pagure-Signature-256
    # https://docs.pagure.org/pagure/usage/using_webhooks.html
    # Custom signature: HTTP_X_OBS_SIGNATURE
    def signature
      @signature ||= @http_request.env['HTTP_X_OBS_SIGNATURE'] ||
                     @http_request.env['HTTP_X_HUB_SIGNATURE_256'] ||
                     @http_request.env['HTTP_X-Pagure-Signature-256']
    end
  end
end
